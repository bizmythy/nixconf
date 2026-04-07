package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

const kittyClass = "kitty"

type daemonState struct {
	mu          sync.RWMutex
	activeClass string
}

var logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{}))

func (s *daemonState) activeWindowClass() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.activeClass
}

func (s *daemonState) setActiveWindowClass(class string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.activeClass = class
}

func main() {
	slog.SetDefault(logger)

	if len(os.Args) < 2 {
		fatal("usage", "message", fmt.Sprintf("usage: %s daemon|left|right|kitty-left|kitty-right", filepath.Base(os.Args[0])))
	}

	switch os.Args[1] {
	case "daemon":
		runDaemon()
	case "left", "right":
		runClient(os.Args[1])
	case "kitty-left":
		runKittyDirection("left")
	case "kitty-right":
		runKittyDirection("right")
	default:
		fatal("unknown subcommand", "subcommand", os.Args[1])
	}
}

func runDaemon() {
	state := &daemonState{}
	if class, err := queryActiveWindowClass(); err == nil {
		state.setActiveWindowClass(class)
	} else {
		logger.Warn("initial Hyprland active window query failed", "error", err)
	}

	stopCh := make(chan struct{})
	go monitorHyprlandEvents(state, stopCh)

	socketPath := clientSocketPath()
	_ = os.Remove(socketPath)

	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		fatal("listen control socket", "path", socketPath, "error", err)
	}
	defer func() {
		_ = listener.Close()
		_ = os.Remove(socketPath)
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigCh
		close(stopCh)
		_ = listener.Close()
	}()

	for {
		conn, err := listener.Accept()
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				return
			}
			logger.Error("accept control socket", "error", err)
			continue
		}

		go func(c net.Conn) {
			defer c.Close()
			if err := handleClientRequest(state, c); err != nil {
				logger.Error("handle request", "error", err)
				_, _ = io.WriteString(c, "error\n")
				return
			}
			_, _ = io.WriteString(c, "ok\n")
		}(conn)
	}
}

func runClient(direction string) {
	conn, err := net.DialTimeout("unix", clientSocketPath(), 150*time.Millisecond)
	if err != nil {
		// Fail open to the original Hyprland behavior if the daemon is down.
		if dispatchMoveFocus(direction); err != nil {
			fatal("control socket unavailable and Hyprland fallback failed", "direction", direction, "error", err)
		}
		return
	}
	defer conn.Close()

	_ = conn.SetDeadline(time.Now().Add(500 * time.Millisecond))
	if _, err := io.WriteString(conn, direction+"\n"); err != nil {
		fatal("write request", "direction", direction, "error", err)
	}
	if unixConn, ok := conn.(*net.UnixConn); ok {
		_ = unixConn.CloseWrite()
	}

	// Drain the daemon response so we notice obvious failures in logs.
	if _, err := io.ReadAll(conn); err != nil && !errors.Is(err, os.ErrDeadlineExceeded) {
		fatal("read response", "direction", direction, "error", err)
	}
}

func handleClientRequest(state *daemonState, conn net.Conn) error {
	request, err := io.ReadAll(conn)
	if err != nil {
		return fmt.Errorf("read request: %w", err)
	}

	direction := strings.TrimSpace(string(request))
	if direction != "left" && direction != "right" {
		return fmt.Errorf("unsupported direction %q", direction)
	}

	if state.activeWindowClass() != kittyClass {
		return dispatchMoveFocus(direction)
	}

	return dispatchKittyShortcut(direction)
}

func runKittyDirection(direction string) {
	targetIndex, ok, err := nextKittyTabIndex(direction)
	if err != nil {
		fatal("kitty tab lookup failed", "direction", direction, "error", err)
	}
	if !ok {
		if err := dispatchMoveFocus(direction); err != nil {
			fatal("Hyprland fallback failed", "direction", direction, "error", err)
		}
		return
	}

	if err := focusKittyTab(targetIndex); err != nil {
		fatal("kitty focus-tab failed", "direction", direction, "target_index", targetIndex, "error", err)
	}
}

func monitorHyprlandEvents(state *daemonState, stopCh <-chan struct{}) {
	backoff := time.Second

	for {
		select {
		case <-stopCh:
			return
		default:
		}

		if err := streamHyprlandEvents(state, stopCh); err != nil {
			logger.Warn("Hyprland event stream disconnected", "error", err)
		}

		select {
		case <-stopCh:
			return
		case <-time.After(backoff):
		}

		if class, err := queryActiveWindowClass(); err == nil {
			state.setActiveWindowClass(class)
		}
	}
}

func streamHyprlandEvents(state *daemonState, stopCh <-chan struct{}) error {
	conn, err := net.Dial("unix", hyprEventSocketPath())
	if err != nil {
		return fmt.Errorf("dial Hyprland event socket: %w", err)
	}
	defer conn.Close()

	go func() {
		<-stopCh
		_ = conn.Close()
	}()

	scanner := bufio.NewScanner(conn)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		event, data, ok := strings.Cut(line, ">>")
		if !ok {
			continue
		}

		if event != "activewindow" {
			continue
		}

		class, _, _ := strings.Cut(data, ",")
		state.setActiveWindowClass(class)
	}

	if err := scanner.Err(); err != nil {
		return err
	}

	return io.EOF
}

func queryActiveWindowClass() (string, error) {
	output, err := hyprlandCommand("j/activewindow")
	if err != nil {
		return "", err
	}

	var payload struct {
		Class string `json:"class"`
	}
	if err := json.Unmarshal(output, &payload); err != nil {
		return "", fmt.Errorf("decode activewindow response: %w", err)
	}

	return payload.Class, nil
}

func dispatchMoveFocus(direction string) error {
	hyprDirection := map[string]string{
		"left":  "l",
		"right": "r",
	}[direction]

	if hyprDirection == "" {
		return fmt.Errorf("unknown Hyprland direction %q", direction)
	}

	_, err := hyprlandCommand("/dispatch movefocus " + hyprDirection)
	return err
}

func dispatchKittyShortcut(direction string) error {
	key := map[string]string{
		"left":  "h",
		"right": "l",
	}[direction]

	if key == "" {
		return fmt.Errorf("unknown kitty direction %q", direction)
	}

	_, err := hyprlandCommand("/dispatch sendshortcut SUPER," + key + ",activewindow")
	return err
}

func hyprlandCommand(command string) ([]byte, error) {
	conn, err := net.Dial("unix", hyprCommandSocketPath())
	if err != nil {
		return nil, fmt.Errorf("dial Hyprland command socket: %w", err)
	}
	defer conn.Close()

	if _, err := io.WriteString(conn, command); err != nil {
		return nil, fmt.Errorf("write Hyprland command %q: %w", command, err)
	}

	if unixConn, ok := conn.(*net.UnixConn); ok {
		_ = unixConn.CloseWrite()
	}

	response, err := io.ReadAll(conn)
	if err != nil {
		return nil, fmt.Errorf("read Hyprland response for %q: %w", command, err)
	}

	return bytes.TrimSpace(response), nil
}

func nextKittyTabIndex(direction string) (int, bool, error) {
	output, err := exec.Command("kitten", "@", "ls").Output()
	if err != nil {
		return 0, false, fmt.Errorf("run kitten @ ls: %w", err)
	}

	var osWindows []map[string]any
	if err := json.Unmarshal(output, &osWindows); err != nil {
		return 0, false, fmt.Errorf("decode kitten @ ls output: %w", err)
	}

	var focusedWindow map[string]any
	for _, candidate := range osWindows {
		if boolField(candidate, "is_focused") {
			focusedWindow = candidate
			break
		}
	}
	if focusedWindow == nil {
		for _, candidate := range osWindows {
			tabs, ok := candidate["tabs"].([]any)
			if !ok {
				continue
			}
			for _, value := range tabs {
				tab, ok := value.(map[string]any)
				if ok && boolField(tab, "is_focused") {
					focusedWindow = candidate
					break
				}
			}
			if focusedWindow != nil {
				break
			}
		}
	}

	if focusedWindow == nil {
		if len(osWindows) == 1 {
			focusedWindow = osWindows[0]
		} else {
			return 0, false, errors.New("could not identify focused kitty OS window")
		}
	}

	tabValues, ok := focusedWindow["tabs"].([]any)
	if !ok {
		return 0, false, errors.New("kitty ls response missing tabs array")
	}

	activeIndex := -1
	for index, value := range tabValues {
		tab, ok := value.(map[string]any)
		if !ok {
			continue
		}
		if boolField(tab, "is_focused") || boolField(tab, "is_active") {
			activeIndex = index
			break
		}
	}

	if activeIndex == -1 {
		return 0, false, errors.New("could not identify active kitty tab")
	}

	switch direction {
	case "left":
		if activeIndex == 0 {
			return 0, false, nil
		}
		return activeIndex - 1, true, nil
	case "right":
		if activeIndex >= len(tabValues)-1 {
			return 0, false, nil
		}
		return activeIndex + 1, true, nil
	default:
		return 0, false, fmt.Errorf("unsupported direction %q", direction)
	}
}

func focusKittyTab(index int) error {
	command := exec.Command("kitten", "@", "focus-tab", "--match", fmt.Sprintf("index:%d", index))

	output, err := command.CombinedOutput()
	if err != nil {
		return fmt.Errorf("run focus-tab index:%d: %w (%s)", index, err, strings.TrimSpace(string(output)))
	}

	return nil
}

func boolField(value map[string]any, field string) bool {
	flagValue, ok := value[field]
	if !ok {
		return false
	}

	boolean, ok := flagValue.(bool)
	return ok && boolean
}

func hyprRuntimeDir() string {
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		fatal("missing runtime dir", "env", "XDG_RUNTIME_DIR")
	}

	signature := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	if signature == "" {
		fatal("missing Hyprland signature", "env", "HYPRLAND_INSTANCE_SIGNATURE")
	}

	return filepath.Join(runtimeDir, "hypr", signature)
}

func hyprCommandSocketPath() string {
	return filepath.Join(hyprRuntimeDir(), ".socket.sock")
}

func hyprEventSocketPath() string {
	return filepath.Join(hyprRuntimeDir(), ".socket2.sock")
}

func clientSocketPath() string {
	runtimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if runtimeDir == "" {
		fatal("missing runtime dir", "env", "XDG_RUNTIME_DIR")
	}

	return filepath.Join(runtimeDir, "kitty-hypr-nav.sock")
}

func fatal(msg string, args ...any) {
	logger.Error(msg, args...)
	os.Exit(1)
}
