package main

import (
	"bufio"
	"encoding/json"
	"net"
	"path/filepath"
	"testing"
)

func TestWaitForPaneInTabRetriesUntilPaneAppears(t *testing.T) {
	client, stop := newTestClient(t, []testAPIResponse{
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

type testAPIResponse struct {
	Result any
	Error  *apiError
}

func newTestClient(t *testing.T, responses []testAPIResponse) (*client, func()) {
	t.Helper()

	socketPath := filepath.Join(t.TempDir(), "herdr.sock")
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{})
	go func() {
		defer close(done)
		defer listener.Close()

		for _, response := range responses {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			handleTestAPIConn(t, conn, response)
		}
	}()

	stop := func() {
		listener.Close()
		<-done
	}
	return &client{socketPath: socketPath}, stop
}

func handleTestAPIConn(t *testing.T, conn net.Conn, testResponse testAPIResponse) {
	t.Helper()
	defer conn.Close()

	line, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil {
		t.Error(err)
		return
	}

	var request struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(line, &request); err != nil {
		t.Error(err)
		return
	}

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
