package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"
)

const workspaceFocusedEvent = "workspace.focused"

type lazygitProcess struct {
	cmd  *exec.Cmd
	done chan error
}

// watchLazygit runs one lazygit process in the active Herdr cwd and restarts it
// whenever Herdr focuses a workspace with a different active cwd.
func watchLazygit(lazygit string) error {
	queryClient, err := newClient()
	if err != nil {
		return fmt.Errorf("create query client: %w", err)
	}
	eventClient, err := newClient()
	if err != nil {
		return fmt.Errorf("create event client: %w", err)
	}

	cwd, err := queryClient.activeLazygitCWD()
	if err != nil {
		return err
	}

	events := make(chan struct{}, 4)
	subscribeDone := make(chan error, 1)
	go func() {
		subscribeDone <- eventClient.subscribeWorkspaceFocused(events)
	}()

	child, err := startLazygitProcess(lazygit, cwd)
	if err != nil {
		return err
	}

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, syscall.SIGHUP, syscall.SIGINT, syscall.SIGTERM)
	defer signal.Stop(signals)

	for {
		select {
		case <-events:
			nextCWD, err := queryClient.activeLazygitCWD()
			if err != nil || samePath(cwd, nextCWD) {
				continue
			}
			if err := child.stop(2 * time.Second); err != nil {
				return err
			}
			child, err = startLazygitProcess(lazygit, nextCWD)
			if err != nil {
				return err
			}
			cwd = nextCWD
		case err := <-child.done:
			return err
		case err := <-subscribeDone:
			_ = child.stop(2 * time.Second)
			return err
		case <-signals:
			return child.stop(2 * time.Second)
		}
	}
}

func (c *client) activeLazygitCWD() (string, error) {
	pane, err := c.currentPaneFor("")
	if err != nil {
		return "", fmt.Errorf("resolve active Herdr pane: %w", err)
	}
	cwd := firstNonEmpty(pane.ForegroundCWD, pane.CWD)
	if cwd == "" {
		return "", errors.New("could not resolve active Herdr cwd")
	}
	return filepath.Clean(cwd), nil
}

func (c *client) subscribeWorkspaceFocused(events chan<- struct{}) error {
	const method = "events.subscribe"
	payload, id, err := c.encodeRequest(method, map[string]any{
		"subscriptions": []map[string]string{
			{"type": workspaceFocusedEvent},
		},
	})
	if err != nil {
		return err
	}

	conn, err := c.dial(method)
	if err != nil {
		return err
	}
	defer conn.Close()

	if _, err := conn.Write(payload); err != nil {
		return fmt.Errorf("write %s request: %w", method, err)
	}

	reader := bufio.NewReader(conn)
	line, err := reader.ReadBytes('\n')
	if err != nil {
		return fmt.Errorf("read %s response: %w", method, err)
	}
	if err := decodeResponse(method, id, line, nil); err != nil {
		return err
	}

	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		if bytes.Contains(scanner.Bytes(), []byte(workspaceFocusedEvent)) {
			select {
			case events <- struct{}{}:
			default:
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read Herdr event stream: %w", err)
	}

	return errors.New("Herdr event stream closed")
}

func startLazygitProcess(lazygit string, cwd string) (*lazygitProcess, error) {
	cmd := exec.Command(lazygit)
	cmd.Dir = cwd
	cmd.Env = os.Environ()
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("start lazygit in %s: %w", cwd, err)
	}

	child := &lazygitProcess{
		cmd:  cmd,
		done: make(chan error, 1),
	}
	go func() {
		child.done <- cmd.Wait()
	}()
	return child, nil
}

func (child *lazygitProcess) stop(timeout time.Duration) error {
	if child == nil || child.cmd == nil || child.cmd.Process == nil {
		return nil
	}

	if err := child.cmd.Process.Signal(syscall.SIGTERM); err != nil && !errors.Is(err, os.ErrProcessDone) {
		return fmt.Errorf("stop lazygit: %w", err)
	}

	select {
	case <-child.done:
		return nil
	case <-time.After(timeout):
		if err := child.cmd.Process.Kill(); err != nil && !errors.Is(err, os.ErrProcessDone) {
			return fmt.Errorf("kill lazygit: %w", err)
		}
		<-child.done
		return nil
	}
}

func samePath(left string, right string) bool {
	if left == "" || right == "" {
		return left == right
	}
	return filepath.Clean(left) == filepath.Clean(right)
}
