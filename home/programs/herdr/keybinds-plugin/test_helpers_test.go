package main

import (
	"bufio"
	"encoding/json"
	"net"
	"path/filepath"
	"testing"
)

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
