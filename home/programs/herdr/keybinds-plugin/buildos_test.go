package main

import (
	"bufio"
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWaitForPaneInTabRetriesUntilPaneAppears(t *testing.T) {
	client, _, stop := newTestClient(t, []testAPIResponse{
		{Result: map[string]any{
			"type":  "pane_list",
			"panes": []any{},
		}},
		{Result: map[string]any{
			"type": "pane_list",
			"panes": []any{
				map[string]any{
					"pane_id":      "w1:p1",
					"tab_id":       "w1:t1",
					"workspace_id": "w1",
				},
			},
		}},
	})
	defer stop()

	pane, err := client.waitForPaneInTab("w1", "w1:t1")
	if err != nil {
		t.Fatal(err)
	}
	if pane.PaneID != "w1:p1" {
		t.Fatalf("waitForPaneInTab pane id = %q, want w1:p1", pane.PaneID)
	}
}

func TestRunPaneUsesHerdrSendInputRPC(t *testing.T) {
	client, requests, stop := newTestClient(t, []testAPIResponse{
		{Result: map[string]any{"type": "pane_input_sent"}},
	})
	defer stop()

	if err := client.runPane("w1:p1", "echo hi"); err != nil {
		t.Fatal(err)
	}
	if len(*requests) != 1 {
		t.Fatalf("captured %d requests, want 1", len(*requests))
	}

	request := (*requests)[0]
	if request.Method != "pane.send_input" {
		t.Fatalf("runPane method = %q, want pane.send_input", request.Method)
	}
	if got := request.Params["pane_id"]; got != "w1:p1" {
		t.Fatalf("runPane pane_id = %#v, want w1:p1", got)
	}
	if got := request.Params["text"]; got != "echo hi" {
		t.Fatalf("runPane text = %#v, want echo hi", got)
	}
	keys, ok := request.Params["keys"].([]any)
	if !ok || len(keys) != 1 || keys[0] != "Enter" {
		t.Fatalf("runPane keys = %#v, want [Enter]", request.Params["keys"])
	}
}

func TestNewBuildosCreatesWorkspaceAndStartsSetupCommand(t *testing.T) {
	client, requests, stop := newTestClient(t, []testAPIResponse{
		{Result: map[string]any{
			"type": "workspace_created",
			"workspace": map[string]any{
				"label":        "buildos-web-test",
				"workspace_id": "w1",
			},
		}},
		{Result: map[string]any{
			"type": "tab_list",
			"tabs": []any{
				map[string]any{
					"focused":      true,
					"label":        "1",
					"number":       1,
					"tab_id":       "w1:t1",
					"workspace_id": "w1",
				},
			},
		}},
		{Result: map[string]any{"type": "tab_renamed"}},
		{Result: map[string]any{
			"type": "pane_list",
			"panes": []any{
				map[string]any{
					"pane_id":      "w1:p1",
					"tab_id":       "w1:t1",
					"workspace_id": "w1",
				},
			},
		}},
		{Result: map[string]any{"type": "pane_input_sent"}},
	})
	defer stop()

	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("HERDR_PLUGIN_STATE_DIR", t.TempDir())
	withStdin(t, "test\n", func() {
		if err := client.newBuildos("nu"); err != nil {
			t.Fatal(err)
		}
	})

	methods := requestMethods(*requests)
	wantMethods := []string{
		"workspace.create",
		"tab.list",
		"tab.rename",
		"pane.list",
		"pane.send_input",
	}
	if strings.Join(methods, ",") != strings.Join(wantMethods, ",") {
		t.Fatalf("request methods = %#v, want %#v", methods, wantMethods)
	}

	create := (*requests)[0]
	if got := create.Params["cwd"]; got != filepath.Join(home, "dirac") {
		t.Fatalf("workspace cwd = %#v, want ~/dirac", got)
	}
	if got := create.Params["label"]; got != "buildos-web-test" {
		t.Fatalf("workspace label = %#v, want buildos-web-test", got)
	}

	run := (*requests)[4]
	if got := run.Params["pane_id"]; got != "w1:p1" {
		t.Fatalf("setup pane id = %#v, want w1:p1", got)
	}
	text, ok := run.Params["text"].(string)
	if !ok {
		t.Fatalf("setup text = %#v, want string", run.Params["text"])
	}
	for _, want := range []string{
		`^"nu"`,
		"buildos-web-test",
		"finish-buildos",
		filepath.Join(home, "dirac", "buildos-web-test"),
		"w1:t1",
	} {
		if !strings.Contains(text, want) {
			t.Fatalf("setup command %q does not contain %q", text, want)
		}
	}
}

type testAPIResponse struct {
	Result any
	Error  *apiError
}

type testAPIRequest struct {
	ID     string         `json:"id"`
	Method string         `json:"method"`
	Params map[string]any `json:"params"`
}

func newTestClient(t *testing.T, responses []testAPIResponse) (*client, *[]testAPIRequest, func()) {
	t.Helper()

	socketPath := filepath.Join(t.TempDir(), "herdr.sock")
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		t.Fatal(err)
	}

	requests := make([]testAPIRequest, 0, len(responses))
	done := make(chan struct{})
	go func() {
		defer close(done)
		defer listener.Close()

		for _, response := range responses {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			handleTestAPIConn(t, conn, response, &requests)
		}
	}()

	stop := func() {
		listener.Close()
		<-done
	}
	return &client{socketPath: socketPath}, &requests, stop
}

func handleTestAPIConn(
	t *testing.T,
	conn net.Conn,
	testResponse testAPIResponse,
	requests *[]testAPIRequest,
) {
	t.Helper()
	defer conn.Close()

	line, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil {
		t.Error(err)
		return
	}

	var request testAPIRequest
	if err := json.Unmarshal(line, &request); err != nil {
		t.Error(err)
		return
	}
	*requests = append(*requests, request)

	result, err := json.Marshal(testResponse.Result)
	if err != nil {
		t.Error(err)
		return
	}
	response := response{
		ID:     request.ID,
		Result: result,
		Error:  testResponse.Error,
	}
	payload, err := json.Marshal(response)
	if err != nil {
		t.Error(err)
		return
	}
	payload = append(payload, '\n')
	if _, err := conn.Write(payload); err != nil {
		t.Error(err)
	}
}

func requestMethods(requests []testAPIRequest) []string {
	methods := make([]string, 0, len(requests))
	for _, request := range requests {
		methods = append(methods, request.Method)
	}
	return methods
}

func withStdin(t *testing.T, input string, action func()) {
	t.Helper()

	oldStdin := os.Stdin
	read, write, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := write.WriteString(input); err != nil {
		t.Fatal(err)
	}
	if err := write.Close(); err != nil {
		t.Fatal(err)
	}

	os.Stdin = read
	defer func() {
		os.Stdin = oldStdin
		read.Close()
	}()

	action()
}
