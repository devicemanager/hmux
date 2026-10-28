//! This integration crate intentionally uses only installed public paths.

use hmux::{
    Browser, BrowserAttachment, BrowserViewerResizeResult, Client, Config, CreateScreenOptions,
    CreationResolution, Error, Machine, Pane, PixelSize, Screen, Selector, Session, Size, Tab,
    Terminal, TerminalAttachment, TerminalWaitExitResult, UndoLayoutOptions, ViewerReleaseResult,
    ViewerResizeResult, Workspace, WorkspaceId,
};

#[test]
fn clean_consumer_imports_high_level_and_raw_namespaces_together() {
    type PublicHandles = (
        Option<Client>,
        Option<Machine>,
        Option<Session>,
        Option<Workspace>,
        Option<Screen>,
        Option<Pane>,
        Option<Tab>,
        Option<Terminal>,
        Option<Browser>,
    );
    fn high_level_types(_: PublicHandles) {}
    fn raw_types(_: hmux::raw::PingRequest, _: Option<hmux::raw::Client>) {}

    let selector = Selector::<WorkspaceId>::name("same name");
    assert_eq!(selector.exact_name(), Some("same name"));
    high_level_types((None, None, None, None, None, None, None, None, None));
    raw_types(hmux::raw::PingRequest::default(), None);
    let _config = Config::from_env_or_default_session("consumer");

    fn typed_recovery_reads(session: &Session, terminal: &Terminal) {
        let _: hmux::Result<CreationResolution> =
            session.creation().resolve("consumer-correlation");
        let _: hmux::Result<TerminalWaitExitResult> = terminal.wait_exit(Some(0));
    }
    let _ = typed_recovery_reads as fn(&Session, &Terminal);
    let _: fn(&mut TerminalAttachment, Size) -> hmux::Result<ViewerResizeResult> =
        TerminalAttachment::resize;
    let _: fn(&mut TerminalAttachment) -> hmux::Result<ViewerReleaseResult> =
        TerminalAttachment::release;
    let _: fn(&mut BrowserAttachment, PixelSize) -> hmux::Result<BrowserViewerResizeResult> =
        BrowserAttachment::resize;
    let _: fn(&mut BrowserAttachment) -> hmux::Result<ViewerReleaseResult> =
        BrowserAttachment::release;
    let _undo = UndoLayoutOptions {
        confirm_close: true,
        confirmation_token: Some("preview-token".to_string()),
    };
    let _creation = CreateScreenOptions::default().correlation_key("consumer-correlation").unwrap();
    fn typed_confirmation(error: Error) -> Option<hmux::ConfirmationRequiredDetails> {
        match error {
            Error::ConfirmationRequired { details, .. } => Some(details),
            _ => None,
        }
    }
    let _ = typed_confirmation as fn(Error) -> Option<hmux::ConfirmationRequiredDetails>;
}

#[test]
fn newly_cataloged_raw_commands_are_public() {
    let _: fn(
        &mut hmux::raw::Client,
        hmux::raw::BrowserFramePresentedRequest,
    ) -> hmux::raw::Result<hmux::raw::BrowserFramePresentedResult> =
        hmux::raw::Client::browser_frame_presented;
    let _: fn(
        &mut hmux::raw::Client,
        hmux::raw::BrowserKeyPressRequest,
    ) -> hmux::raw::Result<hmux::raw::BrowserKeyPressResult> = hmux::raw::Client::browser_key_press;
    let _: fn(
        &mut hmux::raw::Client,
        hmux::raw::BrowserMouseGuardedRequest,
    ) -> hmux::raw::Result<hmux::raw::BrowserMouseGuardedResult> =
        hmux::raw::Client::browser_mouse_guarded;
    let _: fn(
        &mut hmux::raw::Client,
        hmux::raw::BrowserWheelGuardedRequest,
    ) -> hmux::raw::Result<hmux::raw::BrowserWheelGuardedResult> =
        hmux::raw::Client::browser_wheel_guarded;
    let _: fn(
        &mut hmux::raw::Client,
        hmux::raw::ClearHistoryRequest,
    ) -> hmux::raw::Result<hmux::raw::ClearHistoryResult> = hmux::raw::Client::clear_history;
    let _: fn(
        &mut hmux::raw::Client,
        hmux::raw::NewPaneRightRequest,
    ) -> hmux::raw::Result<hmux::raw::NewPaneRightResult> = hmux::raw::Client::new_pane_right;
    let _: fn(
        &mut hmux::raw::Client,
        hmux::raw::SetViewportPaneWidthRequest,
    ) -> hmux::raw::Result<hmux::raw::SetViewportPaneWidthResult> =
        hmux::raw::Client::set_viewport_pane_width;
    let _: fn(
        &mut hmux::raw::Client,
        hmux::raw::UndoLayoutRequest,
    ) -> hmux::raw::Result<hmux::raw::UndoLayoutResult> = hmux::raw::Client::undo_layout;

    assert_eq!(
        [
            hmux::raw::BROWSER_FRAME_PRESENTED_METADATA.name,
            hmux::raw::BROWSER_KEY_PRESS_METADATA.name,
            hmux::raw::BROWSER_MOUSE_GUARDED_METADATA.name,
            hmux::raw::BROWSER_WHEEL_GUARDED_METADATA.name,
            hmux::raw::CLEAR_HISTORY_METADATA.name,
            hmux::raw::NEW_PANE_RIGHT_METADATA.name,
            hmux::raw::SET_VIEWPORT_PANE_WIDTH_METADATA.name,
            hmux::raw::UNDO_LAYOUT_METADATA.name,
        ],
        [
            "browser-frame-presented",
            "browser-key-press",
            "browser-mouse-guarded",
            "browser-wheel-guarded",
            "clear-history",
            "new-pane-right",
            "set-viewport-pane-width",
            "undo-layout",
        ]
    );
}
