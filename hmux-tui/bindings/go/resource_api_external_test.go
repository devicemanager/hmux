package hmux_test

import (
	"context"
	"testing"

	hmux "github.com/manaflow-ai/cmux/cmux-tui/bindings/go"
	"github.com/manaflow-ai/cmux/cmux-tui/bindings/go/raw"
)

func TestResourceCollectionsExposePointerHandles(t *testing.T) {
	var _ func(*hmux.Client, hmux.Selector[hmux.SessionID]) *hmux.Session = (*hmux.Client).Session
	var _ func(*hmux.Client, context.Context, hmux.MachineListOptions) ([]*hmux.Machine, error) = (*hmux.Client).ListMachines
	var _ func(*hmux.Client, context.Context, string) ([]*hmux.Machine, error) = (*hmux.Client).FindMachinesByName
	var _ func(*hmux.Machine, context.Context, hmux.SessionListOptions) ([]*hmux.Session, error) = (*hmux.Machine).ListSessions
	var _ func(*hmux.Machine, context.Context, string) ([]*hmux.Session, error) = (*hmux.Machine).FindSessionsByName
	var _ func(*hmux.Session, context.Context, hmux.WorkspaceListOptions) ([]*hmux.Workspace, error) = (*hmux.Session).ListWorkspaces
	var _ func(*hmux.Session, context.Context, string) ([]*hmux.Workspace, error) = (*hmux.Session).FindWorkspacesByName
	var _ func(*hmux.Workspace, context.Context, hmux.ScreenListOptions) ([]*hmux.Screen, error) = (*hmux.Workspace).ListScreens
	var _ func(*hmux.Workspace, context.Context, string) ([]*hmux.Screen, error) = (*hmux.Workspace).FindScreensByName
	var _ func(*hmux.Screen, context.Context, hmux.PaneListOptions) ([]*hmux.Pane, error) = (*hmux.Screen).ListPanes
	var _ func(*hmux.Screen, context.Context, string) ([]*hmux.Pane, error) = (*hmux.Screen).FindPanesByName
	var _ func(*hmux.Pane, context.Context, hmux.TabListOptions) ([]*hmux.Tab, error) = (*hmux.Pane).ListTabs
	var _ func(*hmux.Pane, context.Context, string) ([]*hmux.Tab, error) = (*hmux.Pane).FindTabsByName
	var _ func(*hmux.Session, context.Context, hmux.TerminalListOptions) ([]*hmux.Terminal, error) = (*hmux.Session).ListTerminals
	var _ func(*hmux.Session, context.Context, string) ([]*hmux.Terminal, error) = (*hmux.Session).FindTerminalsByName
	var _ func(*hmux.Session, context.Context, hmux.BrowserListOptions) ([]*hmux.Browser, error) = (*hmux.Session).ListBrowsers
	var _ func(*hmux.Session, context.Context, string) ([]*hmux.Browser, error) = (*hmux.Session).FindBrowsersByName
	var _ func(*hmux.Session, hmux.Selector[hmux.TerminalID]) *hmux.Terminal = (*hmux.Session).Terminal
	var _ func(*hmux.Session, hmux.Selector[hmux.BrowserID]) *hmux.Browser = (*hmux.Session).Browser
}

func TestCatalogResultMethodsCompileForExternalConsumers(t *testing.T) {
	var _ string = (hmux.ConfirmationRequiredDetails{}).ConfirmationToken
	var _ func(*hmux.Session, context.Context, hmux.SessionSnapshotOptions) (hmux.ResourceSnapshot, error) = (*hmux.Session).Snapshot
	var _ func(*hmux.Session, context.Context, string, hmux.SessionCreationResolveOptions) (hmux.CreationResolution, error) = (*hmux.Session).ResolveCreation
	var _ func(*hmux.Session, context.Context, hmux.SessionPingOptions) (hmux.PingResult, error) = (*hmux.Session).Ping
	var _ func(*hmux.Session, context.Context, hmux.SessionShutdownOptions) (hmux.MutationResult[hmux.ShutdownResult], error) = (*hmux.Session).Shutdown
	var _ func(*hmux.Session, context.Context, hmux.SessionReloadConfigOptions) (hmux.MutationResult[hmux.ReloadConfigResult], error) = (*hmux.Session).ReloadConfig
	var _ func(*hmux.Session, context.Context, hmux.SessionTerminalDefaultsUpdateOptions) (hmux.MutationResult[hmux.TerminalDefaultsSnapshot], error) = (*hmux.Session).UpdateTerminalDefaults
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalScreenReadOptions) (hmux.TerminalScreenResult, error) = (*hmux.Terminal).ReadScreen
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalStateReadOptions) (hmux.TerminalStateResult, error) = (*hmux.Terminal).ReadState
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalHistoryReadOptions) (hmux.TerminalHistoryResult, error) = (*hmux.Terminal).ReadHistory
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalWaitOptions) (hmux.TerminalWaitResult, error) = (*hmux.Terminal).Wait
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalWaitExitOptions) (hmux.TerminalWaitExitResult, error) = (*hmux.Terminal).WaitExit
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalCopyOptions) (hmux.TerminalCopyResult, error) = (*hmux.Terminal).Copy
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalProcessGetOptions) (hmux.ProcessInfoResult, error) = (*hmux.Terminal).Process
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalViewerResizeOptions) (hmux.ViewerResizeResult, error) = (*hmux.Terminal).ResizeViewer
	var _ func(*hmux.Browser, context.Context, hmux.BrowserViewerResizeOptions) (hmux.BrowserViewerResizeResult, error) = (*hmux.Browser).ResizeViewer
	var _ func(*hmux.ConnectedClient, context.Context, hmux.ConnectedClientCellPixelsSetOptions) (hmux.CellPixelsResult, error) = (*hmux.ConnectedClient).SetCellPixels
	var _ func(*hmux.Workspace, context.Context, hmux.WorkspaceRenameOptions) (hmux.MutationResult[*hmux.Workspace], error) = (*hmux.Workspace).Rename
	var _ func(*hmux.Screen, context.Context, hmux.ScreenRenameOptions) (hmux.MutationResult[*hmux.Screen], error) = (*hmux.Screen).Rename
	var _ func(*hmux.Pane, context.Context, hmux.PaneRenameOptions) (hmux.MutationResult[*hmux.Pane], error) = (*hmux.Pane).Rename
	var _ func(*hmux.Tab, context.Context, hmux.TabRenameOptions) (hmux.MutationResult[*hmux.Tab], error) = (*hmux.Tab).Rename
	var _ func(*hmux.Terminal, context.Context, hmux.TerminalMoveOptions) (hmux.MutationResult[*hmux.Terminal], error) = (*hmux.Terminal).Move
	var _ func(*hmux.Browser, context.Context, hmux.BrowserNavigateOptions) (hmux.MutationResult[*hmux.Browser], error) = (*hmux.Browser).Navigate
	var _ func(*hmux.PairingRequest, context.Context, hmux.PairingRequestResolveOptions) (hmux.MutationResult[*hmux.PairingRequest], error) = (*hmux.PairingRequest).Resolve
	var _ func(*hmux.FrontendProjection, context.Context, hmux.FrontendProjectionPutOptions) (hmux.MutationResult[*hmux.FrontendProjection], error) = (*hmux.FrontendProjection).Put
	var _ func(*hmux.Session, context.Context, hmux.AgentReportOptions) (hmux.MutationResult[*hmux.Agent], error) = (*hmux.Session).ReportAgent
	var _ func(*hmux.SidebarView, context.Context, hmux.SidebarViewResizeOptions) (hmux.MutationResult[*hmux.SidebarView], error) = (*hmux.SidebarView).Resize
}

func externalConsumerCompiles(
	client *hmux.Client,
	highLevel hmux.WorkspaceID,
	lowLevel *raw.Client,
) {
	_ = client.Machine(hmux.SelectCurrent[hmux.MachineID]()).
		Session(hmux.SelectCurrent[hmux.SessionID]()).
		Workspace(hmux.SelectID(highLevel))
	_, _ = lowLevel.Identify(context.Background())
}
