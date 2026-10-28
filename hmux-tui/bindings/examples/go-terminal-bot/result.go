package terminalbot

import (
	"fmt"

	hmux "github.com/manaflow-ai/cmux/cmux-tui/bindings/go"
)

// Result contains typed resource IDs and captured terminal state.
type Result struct {
	Workspace    hmux.WorkspaceID
	Screen       hmux.ScreenID
	Pane         hmux.PaneID
	Tab          hmux.TabID
	Terminal     hmux.TerminalID
	Notification hmux.NotificationID

	WorkspaceRevision hmux.Decimal
	TerminalRevision  hmux.Decimal
	ExitCode          int
	ScreenText        string
	HistoryText       string
	Warnings          []string
}

// TaskError reports a completed command with a nonzero exit status.
type TaskError struct {
	ExitCode int
}

func (err *TaskError) Error() string {
	return fmt.Sprintf("terminal task exited with status %d", err.ExitCode)
}
