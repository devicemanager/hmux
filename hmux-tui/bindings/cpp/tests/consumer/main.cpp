#include <hmux/client.hpp>
#include <hmux/raw/client.hpp>
#include <hmux/version.hpp>

#include <cstdint>
#include <optional>
#include <type_traits>
#include <utility>

static_assert(std::is_same_v<
              decltype(std::declval<hmux::Workspace&>().refresh()),
              hmux::Result<hmux::WorkspaceSnapshot>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Terminal&>().wait_exit()),
              hmux::Result<hmux::TerminalWaitExitResult>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Terminal&>().read_history(
                  std::declval<hmux::TerminalHistoryOptions>())),
              hmux::Result<hmux::TerminalHistoryResult>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Terminal&>().attach(
                  std::declval<hmux::TerminalAttachOptions>(),
                  std::declval<hmux::CallOptions>())),
              hmux::Result<hmux::TerminalAttachmentStream>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::BrowserAttachFrame>()
                           .pointer_frame_seq),
              std::optional<std::uint64_t>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Browser&>().mouse(
                  std::declval<hmux::Json::Object>(),
                  std::declval<std::uint64_t>(),
                  std::declval<hmux::MutationOptions>())),
              hmux::Result<hmux::MutationResult<hmux::EmptyResult>>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Browser&>().wheel(
                  std::declval<double>(),
                  std::declval<double>(),
                  std::declval<double>(),
                  std::declval<double>(),
                  std::declval<std::uint64_t>(),
                  std::declval<hmux::MutationOptions>())),
              hmux::Result<hmux::MutationResult<hmux::EmptyResult>>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Workspace&>().run(
                  std::declval<hmux::RunOptions>(),
                  std::declval<hmux::MutationOptions>(),
                  std::declval<hmux::CallOptions>())),
              hmux::Result<
                  hmux::MutationResult<hmux::CreatedTerminalPath>>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Session&>().notifications()),
              hmux::Result<std::vector<hmux::NotificationSnapshot>>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Session&>().create_notification(
                  std::declval<hmux::NotificationCreateOptions>(),
                  std::declval<hmux::MutationOptions>())),
              hmux::Result<
                  hmux::MutationResult<hmux::NotificationSnapshot>>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::Session&>().report_agent(
                  std::declval<hmux::AgentReportOptions>(),
                  std::declval<hmux::MutationOptions>())),
              hmux::Result<hmux::MutationResult<hmux::AgentSnapshot>>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().identify()),
              hmux::Result<hmux::raw::IdentifyResult>>);
static_assert(!std::is_copy_constructible_v<hmux::SessionEventStream>);
static_assert(std::is_nothrow_move_constructible_v<hmux::SessionEventStream>);

int main() {
    auto id = hmux::WorkspaceId::parse(
        "ws_0123456789abcdef0123456789abcdef");
    if (!id) {
        return 1;
    }
    const auto selector =
        hmux::Selector<hmux::WorkspaceId>::exact_name("current");
    auto command = hmux::RunCommand::exact({"cargo", "test"});
    if (!command || command.value().argv().size() != 2) {
        return 1;
    }

    hmux::CreateWorkspaceOptions workspace_create;
    workspace_create.correlation_key = "consumer-workspace";
    auto workspace_params = workspace_create.to_params();

    hmux::RunOptions run(std::move(command).value());
    run.correlation_key = "consumer-run";
    auto run_params = run.to_params();

    hmux::CreateScreenOptions screen_create;
    screen_create.correlation_key = "consumer-screen";
    auto screen_params = screen_create.to_params();

    hmux::CreatePaneOptions pane_create;
    pane_create.correlation_key = "consumer-pane";
    auto pane_params = pane_create.to_params();

    hmux::SplitPaneOptions pane_split(hmux::PaneDirection::right);
    pane_split.correlation_key = "consumer-split";
    pane_split.viewport_width = 0.5;
    auto split_params = pane_split.to_params();

    hmux::CreateTerminalTabOptions terminal_create;
    terminal_create.correlation_key = "consumer-terminal";
    auto terminal_params = terminal_create.to_params();

    hmux::CreateBrowserTabOptions browser_create("https://example.com");
    browser_create.correlation_key = "consumer-browser";
    auto browser_params = browser_create.to_params();

    hmux::TerminalHistoryOptions history;
    history.before = 50;
    history.limit = 100;
    history.styled = true;
    auto history_params = history.to_params();

    hmux::TerminalAttachOptions attach;
    attach.cols = 120;
    attach.rows = 40;
    attach.read_only = true;
    auto attach_params = attach.to_params();

    auto terminal_id = hmux::TerminalId::parse(
        "term_0123456789abcdef0123456789abcdef");
    if (!terminal_id) {
        return 1;
    }
    hmux::NotificationCreateOptions notification("build", "complete");
    notification.level = hmux::NotificationLevel::info;
    notification.terminal_id = terminal_id.value();
    auto notification_params = notification.to_params();

    hmux::AgentReportOptions agent(
        terminal_id.value(),
        hmux::AgentState::working,
        hmux::AgentReportSource::socket);
    agent.source_session = "consumer";
    auto agent_params = agent.to_params();

    hmux::raw::IdentifyRequest raw_request;
    return selector.wire() != "name:current" ||
                   !workspace_params || !run_params || !screen_params ||
                   !pane_params || !split_params || !terminal_params ||
                   !browser_params || !history_params || !attach_params ||
                   !notification_params || !agent_params ||
                   workspace_params.value()
                           .at("correlation_key")
                           .as_string()
                           .value() != "consumer-workspace" ||
                   run_params.value()
                           .at("correlation_key")
                           .as_string()
                           .value() != "consumer-run" ||
                   screen_params.value()
                           .at("correlation_key")
                           .as_string()
                           .value() != "consumer-screen" ||
                   pane_params.value()
                           .at("correlation_key")
                           .as_string()
                           .value() != "consumer-pane" ||
                   split_params.value()
                           .at("correlation_key")
                           .as_string()
                           .value() != "consumer-split" ||
                   terminal_params.value()
                           .at("correlation_key")
                           .as_string()
                           .value() != "consumer-terminal" ||
                   browser_params.value()
                           .at("correlation_key")
                           .as_string()
                           .value() != "consumer-browser" ||
                   history_params.value()
                           .at("before")
                           .as_string()
                           .value() != "50" ||
                   history_params.value()
                           .at("limit")
                           .as_uint64()
                           .value() != 100 ||
                   attach_params.value()
                           .at("cols")
                           .as_uint64()
                           .value() != 120 ||
                   !attach_params.value()
                            .at("read_only")
                            .as_bool()
                            .value() ||
                   notification_params.value()
                           .at("level")
                           .as_string()
                           .value() != "info" ||
                   agent_params.value()
                           .at("source")
                           .as_string()
                           .value() != "socket" ||
                   !(raw_request == hmux::raw::IdentifyRequest{}) ||
                   hmux::kSdkVersion != "1.0.0"
               ? 1
               : 0;
}
