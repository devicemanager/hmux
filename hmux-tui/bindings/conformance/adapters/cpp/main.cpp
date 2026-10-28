#include <hmux/client.hpp>

#include <algorithm>
#include <charconv>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <map>
#include <optional>
#include <set>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <system_error>
#include <utility>
#include <variant>
#include <vector>

namespace {

class AdapterError final : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

[[nodiscard]] std::string describe(const hmux::Error& error) {
    std::string result = error.protocol_code.empty()
        ? error.code_name()
        : error.protocol_code;
    result += ": ";
    result += error.message;
    return result;
}

template <typename T>
[[nodiscard]] T take(hmux::Result<T> result) {
    if (!result) {
        throw AdapterError(describe(result.error()));
    }
    return std::move(result).value();
}

[[nodiscard]] const hmux::Json& field(
    const hmux::Json& value,
    std::string_view name) {
    const auto* result = value.find(name);
    if (!result) {
        throw AdapterError("missing JSON field: " + std::string(name));
    }
    return *result;
}

[[nodiscard]] std::string string_value(const hmux::Json& value) {
    auto text = value.as_string();
    if (!text) {
        throw AdapterError("expected a JSON string");
    }
    return std::string(text.value());
}

[[nodiscard]] std::string string_field(
    const hmux::Json& value,
    std::string_view name) {
    return string_value(field(value, name));
}

[[nodiscard]] std::uint64_t decimal(std::string_view text) {
    std::uint64_t value = 0;
    const auto [end, error] =
        std::from_chars(text.data(), text.data() + text.size(), value);
    if (error != std::errc{} || end != text.data() + text.size()) {
        throw AdapterError("invalid unsigned decimal: " + std::string(text));
    }
    return value;
}

template <typename Id>
[[nodiscard]] Id opaque_id(std::string_view value) {
    auto parsed = Id::parse(value);
    if (!parsed) {
        throw AdapterError(describe(parsed.error()));
    }
    return std::move(parsed).value();
}

[[nodiscard]] const hmux::Json& constants(const hmux::Json& request) {
    return field(request, "constants");
}

[[nodiscard]] hmux::MutationOptions mutation_options(
    const hmux::Json& request,
    std::string_view key_name = "idempotency_key") {
    const auto& values = constants(request);
    auto options = take(hmux::MutationOptions::with_key(
        string_field(values, key_name)));
    return options.expecting(decimal(string_field(values, "revision")));
}

[[nodiscard]] hmux::Client connect(
    const hmux::Json& request,
    std::string session_selector) {
    hmux::ClientOptions options;
    options.socket_path = string_field(request, "socket_path");
    options.machine_selector = "current";
    options.session_selector = std::move(session_selector);
    options.timeout = std::chrono::seconds(15);
    return take(hmux::Client::connect(std::move(options)));
}

[[nodiscard]] hmux::Session session(
    hmux::Client& client,
    const hmux::Json& request) {
    return client.session(opaque_id<hmux::SessionId>(
        string_field(constants(request), "session")));
}

[[nodiscard]] hmux::Workspace workspace(
    hmux::Client& client,
    const hmux::Json& request) {
    return client.workspace(opaque_id<hmux::WorkspaceId>(
        string_field(constants(request), "workspace")));
}

[[nodiscard]] std::string end_name(hmux::StreamEndReason reason) {
    switch (reason) {
        case hmux::StreamEndReason::completed:
            return "completed";
        case hmux::StreamEndReason::canceled:
            return "canceled";
        case hmux::StreamEndReason::closed:
            return "closed";
        case hmux::StreamEndReason::gap:
            return "gap";
        case hmux::StreamEndReason::error:
            return "error";
    }
    throw AdapterError("unknown stream end reason");
}

[[nodiscard]] const hmux::StreamEnd& require_end(
    const hmux::SessionEventStream& stream) {
    if (!stream.end()) {
        throw AdapterError("stream ended without terminal metadata");
    }
    return *stream.end();
}

[[nodiscard]] hmux::Json cursor_json(const hmux::Cursor& cursor) {
    return hmux::Json(hmux::Json::Object{
        {"generation", hmux::Json(cursor.generation)},
        {"revision", hmux::Json(std::to_string(cursor.revision))},
    });
}

[[nodiscard]] hmux::Json mutation_json(
    const hmux::MutationResult<hmux::WorkspaceSnapshot>& result) {
    return hmux::Json(hmux::Json::Object{
        {"workspace_id", hmux::Json(result.value.id.value())},
        {"name", hmux::Json(result.value.name)},
        {"generation", hmux::Json(result.generation)},
        {"revision", hmux::Json(std::to_string(result.revision))},
        {"replayed", hmux::Json(result.replayed)},
    });
}

[[nodiscard]] hmux::Json error_json(const hmux::Error& error) {
    return hmux::Json(hmux::Json::Object{
        {"code", hmux::Json(error.protocol_code)},
        {"message", hmux::Json(error.message)},
        {"details",
         error.details ? *error.details : hmux::Json(hmux::Json::Object{})},
        {"retryable", hmux::Json(error.retryable)},
    });
}

[[nodiscard]] hmux::Json created_path_json(const hmux::CreatedPath& path) {
    if (const auto* value =
            std::get_if<hmux::CreatedWorkspaceOnly>(&path)) {
        return hmux::Json(hmux::Json::Object{
            {"kind", hmux::Json("workspace")},
            {"workspace_id", hmux::Json(value->workspace_id.value())},
        });
    }
    if (const auto* value =
            std::get_if<hmux::CreatedTerminalPath>(&path)) {
        return hmux::Json(hmux::Json::Object{
            {"kind", hmux::Json("terminal")},
            {"workspace_id", hmux::Json(value->workspace_id.value())},
            {"screen_id", hmux::Json(value->screen_id.value())},
            {"pane_id", hmux::Json(value->pane_id.value())},
            {"tab_id", hmux::Json(value->tab_id.value())},
            {"terminal_id", hmux::Json(value->terminal_id.value())},
        });
    }
    const auto& value = std::get<hmux::CreatedBrowserPath>(path);
    return hmux::Json(hmux::Json::Object{
        {"kind", hmux::Json("browser")},
        {"workspace_id", hmux::Json(value.workspace_id.value())},
        {"screen_id", hmux::Json(value.screen_id.value())},
        {"pane_id", hmux::Json(value.pane_id.value())},
        {"tab_id", hmux::Json(value.tab_id.value())},
        {"browser_id", hmux::Json(value.browser_id.value())},
    });
}

[[nodiscard]] std::string creation_state_name(hmux::CreationState state) {
    switch (state) {
        case hmux::CreationState::pending:
            return "pending";
        case hmux::CreationState::created:
            return "created";
        case hmux::CreationState::not_applied:
            return "not_applied";
        case hmux::CreationState::indeterminate:
            return "indeterminate";
    }
    throw AdapterError("unknown creation state");
}

[[nodiscard]] std::string creation_recovery_name(
    hmux::CreationRecovery recovery) {
    switch (recovery) {
        case hmux::CreationRecovery::retry_same_idempotency_key:
            return "retry_same_idempotency_key";
        case hmux::CreationRecovery::retry_new_idempotency_key:
            return "retry_new_idempotency_key";
        case hmux::CreationRecovery::wait:
            return "wait";
        case hmux::CreationRecovery::none:
            return "none";
        case hmux::CreationRecovery::do_not_retry:
            return "do_not_retry";
    }
    throw AdapterError("unknown creation recovery");
}

[[nodiscard]] hmux::Json creation_resolution_json(
    const hmux::CreationResolution& resolution) {
    hmux::Json::Object result{
        {"correlation_key", hmux::Json(resolution.correlation_key)},
        {"state", hmux::Json(creation_state_name(resolution.state))},
        {"recovery", hmux::Json(creation_recovery_name(resolution.recovery))},
    };
    if (resolution.operation) {
        result.emplace("operation", hmux::Json(*resolution.operation));
    }
    if (resolution.idempotency_key) {
        result.emplace(
            "idempotency_key",
            hmux::Json(*resolution.idempotency_key));
    }
    if (resolution.created_path) {
        result.emplace(
            "created_path",
            created_path_json(*resolution.created_path));
    }
    if (resolution.generation) {
        result.emplace("generation", hmux::Json(*resolution.generation));
    }
    if (resolution.revision) {
        result.emplace(
            "revision",
            hmux::Json(std::to_string(*resolution.revision)));
    }
    return hmux::Json(std::move(result));
}

[[nodiscard]] hmux::Json exit_outcome_json(
    const hmux::TerminalExitOutcome& outcome) {
    if (const auto* value = std::get_if<hmux::TerminalExitCode>(&outcome)) {
        return hmux::Json(hmux::Json::Object{
            {"kind", hmux::Json("exit")},
            {"code", hmux::Json(std::int64_t{value->code})},
        });
    }
    if (const auto* value =
            std::get_if<hmux::TerminalExitSignal>(&outcome)) {
        return hmux::Json(hmux::Json::Object{
            {"kind", hmux::Json("signal")},
            {"signal", hmux::Json(std::int64_t{value->signal})},
            {"core_dumped", hmux::Json(value->core_dumped)},
        });
    }
    const auto& value = std::get<hmux::TerminalExitUnknown>(outcome);
    return hmux::Json(hmux::Json::Object{
        {"kind", hmux::Json("unknown")},
        {"reason", hmux::Json(value.reason)},
    });
}

[[nodiscard]] hmux::Json terminal_wait_exit_json(
    const hmux::TerminalWaitExitResult& result) {
    if (const auto* value =
            std::get_if<hmux::TerminalWaitExitPending>(&result)) {
        return hmux::Json(hmux::Json::Object{
            {"state", hmux::Json("pending")},
            {"terminal_id", hmux::Json(value->terminal_id.value())},
            {"lifecycle", hmux::Json(value->lifecycle)},
            {"revision", hmux::Json(std::to_string(value->revision))},
        });
    }
    const auto& value = std::get<hmux::TerminalWaitExitExited>(result);
    return hmux::Json(hmux::Json::Object{
        {"state", hmux::Json("exited")},
        {"terminal_id", hmux::Json(value.terminal_id.value())},
        {"lifecycle", hmux::Json("exited")},
        {"outcome", exit_outcome_json(value.outcome)},
        {"exited_at", hmux::Json(std::to_string(value.exited_at))},
        {"revision", hmux::Json(std::to_string(value.revision))},
    });
}

[[nodiscard]] hmux::Json run_read(const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    const auto result = take(session(client, request).ping());
    return hmux::Json(hmux::Json::Object{
        {"alive", hmux::Json(result.alive)},
        {"cursor", cursor_json(result.cursor)},
    });
}

[[nodiscard]] hmux::Json run_creation_resolve(
    const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    const auto result = take(session(client, request).resolve_creation(
        string_field(constants(request), "correlation_key")));
    return creation_resolution_json(result);
}

[[nodiscard]] hmux::Json run_creation_conflict(
    const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    hmux::CreateWorkspaceOptions create;
    create.name = string_field(constants(request), "name");
    create.initial_content = hmux::InitialContent::empty;
    create.correlation_key =
        string_field(constants(request), "correlation_key");
    auto result = session(client, request).create_workspace(
        std::move(create),
        take(hmux::MutationOptions::with_key(
            string_field(constants(request), "idempotency_key"))));
    if (result) {
        throw AdapterError("creation conflict unexpectedly succeeded");
    }
    return error_json(result.error());
}

[[nodiscard]] hmux::Json run_terminal_wait_exit(
    const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    auto terminal = client.terminal(opaque_id<hmux::TerminalId>(
        string_field(constants(request), "terminal")));
    const auto timeout = decimal(string_field(request, "timeout_ms"));
    return terminal_wait_exit_json(take(terminal.wait_exit(timeout)));
}

[[nodiscard]] hmux::Json run_mutation_replay(const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    auto target = workspace(client, request);
    const auto name = string_field(constants(request), "name");
    const auto options = mutation_options(request);
    const auto first = take(target.rename(name, options));
    const auto second = take(target.rename(name, options));
    return hmux::Json(hmux::Json::Object{
        {"first", mutation_json(first)},
        {"second", mutation_json(second)},
    });
}

[[nodiscard]] hmux::Json run_mutation_error(const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    auto result = workspace(client, request).rename(
        string_field(constants(request), "name"),
        mutation_options(request));
    if (result) {
        throw AdapterError("mutation unexpectedly succeeded");
    }
    return error_json(result.error());
}

[[nodiscard]] hmux::Json run_stream_unknown(const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    auto stream = take(session(client, request).events());
    auto next = take(stream.next());
    if (!next) {
        throw AdapterError("unknown stream ended before its item");
    }
    if (!next->cursor) {
        throw AdapterError("unknown stream item omitted its cursor");
    }
    auto terminal = take(stream.next());
    if (terminal) {
        throw AdapterError("unknown stream produced an unexpected second item");
    }
    const auto* unknown = std::get_if<hmux::Unknown>(&next->value);
    if (!unknown) {
        throw AdapterError(
            "session event was not the public Unknown variant");
    }
    return hmux::Json(hmux::Json::Object{
        {"sequence", hmux::Json(std::to_string(next->sequence))},
        {"cursor", cursor_json(*next->cursor)},
        {"kind", hmux::Json(unknown->kind)},
        {"raw", unknown->raw},
        {"end", hmux::Json(end_name(require_end(stream).reason))},
    });
}

[[nodiscard]] hmux::Json run_stream_cancel(const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    auto stream = take(session(client, request).events());
    const auto first = take(stream.cancel());
    const auto second = take(stream.cancel());
    std::uint64_t after = 0;
    while (take(stream.next())) {
        ++after;
    }
    if (first.reason != second.reason) {
        throw AdapterError("repeated cancel changed the terminal reason");
    }
    return hmux::Json(hmux::Json::Object{
        {"end", hmux::Json(end_name(second.reason))},
        {"items_after_cancel", hmux::Json(after)},
        {"cancel_calls", hmux::Json(std::uint64_t{2})},
    });
}

[[nodiscard]] std::string drain(hmux::SessionEventStream& stream) {
    while (take(stream.next())) {
    }
    return end_name(require_end(stream).reason);
}

[[nodiscard]] hmux::Json run_stream_overflow(const hmux::Json& request) {
    auto client = connect(
        request, string_field(constants(request), "session"));
    auto current_session = session(client, request);
    auto first = take(current_session.events());
    const auto first_end = drain(first);

    auto second = take(current_session.events());
    auto item = take(second.next());
    if (!item) {
        throw AdapterError("independent stream ended before its item");
    }
    const auto* unknown = std::get_if<hmux::Unknown>(&item->value);
    if (!unknown) {
        throw AdapterError(
            "independent stream item was not the public Unknown variant");
    }
    const auto second_kind = unknown->kind;
    if (take(second.next())) {
        throw AdapterError("independent stream produced an extra item");
    }
    const auto control = take(current_session.ping());
    return hmux::Json(hmux::Json::Object{
        {"first_end", hmux::Json(first_end)},
        {"second_kind", hmux::Json(second_kind)},
        {"control_alive", hmux::Json(control.alive)},
    });
}

[[nodiscard]] hmux::Json run_redaction() {
    constexpr std::string_view specifier_secret =
        "provider://conformance-secret";
    constexpr std::string_view renderer_secret =
        "renderer-conformance-secret";
    hmux::SensitiveString specifier{std::string(specifier_secret)};
    hmux::RendererGrant grant{
        "unix:///tmp/renderer",
        opaque_id<hmux::TerminalId>(
            "term_66666666666666666666666666666666"),
        hmux::SensitiveString(std::string(renderer_secret)),
        {"render"},
        1000,
    };
    std::ostringstream specifier_text;
    specifier_text << specifier;
    std::ostringstream grant_text;
    grant_text << grant;
    return hmux::Json(hmux::Json::Object{
        {"specifier_redacted",
         hmux::Json(
             specifier_text.str().find(specifier_secret) == std::string::npos)},
        {"renderer_token_redacted",
         hmux::Json(
             grant_text.str().find(renderer_secret) == std::string::npos)},
    });
}

[[nodiscard]] hmux::MutationOptions key(
    std::string_view prefix,
    std::string_view suffix) {
    return take(hmux::MutationOptions::with_key(
        std::string(prefix) + "-" + std::string(suffix)));
}

[[nodiscard]] hmux::WorkspaceId create_empty_workspace(
    hmux::Session& session,
    std::string name,
    hmux::MutationOptions mutation) {
    hmux::CreateWorkspaceOptions create;
    create.name = std::move(name);
    create.initial_content = hmux::InitialContent::empty;
    auto created = take(session.create_workspace(
        std::move(create), std::move(mutation)));
    return std::visit(
        [](const auto& value) { return value.workspace_id; },
        created.value);
}

[[nodiscard]] std::map<std::string, std::string> workspace_rows(
    hmux::Session& session) {
    const auto listed = take(session.workspaces());
    std::map<std::string, std::string> rows;
    for (const auto& item : listed) {
        rows.emplace(item.id.value(), item.name);
    }
    return rows;
}

[[nodiscard]] std::vector<std::string> string_array_field(
    const hmux::Json& value,
    std::string_view name) {
    auto array = field(value, name).as_array();
    if (!array) {
        throw AdapterError(
            "expected a JSON string array: " + std::string(name));
    }
    std::vector<std::string> result;
    result.reserve(array.value()->size());
    for (const auto& item : *array.value()) {
        result.push_back(string_value(item));
    }
    return result;
}

[[nodiscard]] hmux::Json string_array_json(
    const std::vector<std::string>& values) {
    hmux::Json::Array result;
    result.reserve(values.size());
    for (const auto& value : values) {
        result.emplace_back(value);
    }
    return hmux::Json(std::move(result));
}

[[nodiscard]] hmux::Json run_live_setup(const hmux::Json& request) {
    auto client = connect(request, "current");
    auto current =
        client.session(hmux::Selector<hmux::SessionId>::current());
    const auto pinged = take(current.ping()).alive;
    const auto base = string_field(request, "workspace_name");
    const auto key_prefix = string_field(request, "key_prefix");

    const auto stable_id = create_empty_workspace(
        current, base, key(key_prefix, "stable-create"));
    const auto renamed_name = base + "-renamed";
    const auto renamed = take(
        current.workspace(stable_id).rename(
            renamed_name,
            key(key_prefix, "stable-rename")));
    const auto stable_renamed = renamed.value.name == renamed_name;

    const auto duplicate_name = base + "-duplicate";
    std::vector<std::string> duplicate_ids;
    duplicate_ids.reserve(2);
    for (const auto suffix : {"duplicate-a", "duplicate-b"}) {
        duplicate_ids.push_back(
            create_empty_workspace(
                current,
                duplicate_name,
                key(key_prefix, suffix))
                .value());
    }

    auto ambiguity =
        current.workspace(
                   hmux::Selector<hmux::WorkspaceId>::exact_name(
                       duplicate_name))
            .rename(
                base + "-must-not-apply",
                key(key_prefix, "ambiguous-rename"));
    if (ambiguity) {
        throw AdapterError(
            "duplicate workspace selector unexpectedly mutated");
    }
    const auto ambiguity_code = ambiguity.error().protocol_code;
    std::vector<std::string> ambiguity_candidates;
    if (ambiguity.error().details) {
        if (const auto* candidates =
                ambiguity.error().details->find("candidates")) {
            auto array = candidates->as_array();
            if (array) {
                ambiguity_candidates.reserve(array.value()->size());
                for (const auto& candidate : *array.value()) {
                    ambiguity_candidates.push_back(string_value(candidate));
                }
            }
        }
    }
    const std::set<std::string> expected_candidates(
        duplicate_ids.begin(), duplicate_ids.end());
    const std::set<std::string> observed_candidates(
        ambiguity_candidates.begin(), ambiguity_candidates.end());
    const auto candidates_preserved =
        ambiguity_candidates.size() == duplicate_ids.size() &&
        observed_candidates == expected_candidates;

    const auto rows = workspace_rows(current);
    const auto no_mutation =
        rows.contains(stable_id.value()) &&
        rows.at(stable_id.value()) == renamed_name &&
        std::ranges::all_of(
            duplicate_ids,
            [&rows, &duplicate_name](const auto& identifier) {
                const auto found = rows.find(identifier);
                return found != rows.end() &&
                       found->second == duplicate_name;
            }) &&
        std::ranges::none_of(
            rows,
            [&base](const auto& entry) {
                return entry.second == base + "-must-not-apply";
            });

    return hmux::Json(hmux::Json::Object{
        {"pinged", hmux::Json(pinged)},
        {"stable_id", hmux::Json(stable_id.value())},
        {"stable_renamed", hmux::Json(stable_renamed)},
        {"duplicate_ids", string_array_json(duplicate_ids)},
        {"ambiguity_code", hmux::Json(ambiguity_code)},
        {"ambiguity_preserved_all_candidates",
         hmux::Json(candidates_preserved)},
        {"no_mutation", hmux::Json(no_mutation)},
    });
}

[[nodiscard]] const hmux::TerminalWaitExitPending& require_pending(
    const hmux::TerminalWaitExitResult& result) {
    const auto* value =
        std::get_if<hmux::TerminalWaitExitPending>(&result);
    if (!value) {
        throw AdapterError("terminal wait did not return pending");
    }
    return *value;
}

[[nodiscard]] const hmux::TerminalWaitExitExited& require_exited(
    const hmux::TerminalWaitExitResult& result) {
    const auto* value =
        std::get_if<hmux::TerminalWaitExitExited>(&result);
    if (!value) {
        throw AdapterError("terminal wait did not return an exit");
    }
    return *value;
}

[[nodiscard]] const hmux::TerminalExitCode& require_exit_code(
    const hmux::TerminalExitOutcome& outcome) {
    const auto* value = std::get_if<hmux::TerminalExitCode>(&outcome);
    if (!value) {
        throw AdapterError("terminal did not exit with an exit code");
    }
    return *value;
}

[[nodiscard]] hmux::Json run_live_creation_exit(
    const hmux::Json& request) {
    auto client = connect(request, "current");
    auto current =
        client.session(hmux::Selector<hmux::SessionId>::current());
    auto workspace = current.workspace(opaque_id<hmux::WorkspaceId>(
        string_field(request, "expected_stable_id")));
    const auto key_prefix = string_field(request, "key_prefix");
    const auto screen_created = take(workspace.create_screen(
        {},
        key(key_prefix, "runtime-screen")));
    const auto& screen_path = screen_created.value;
    auto pane = workspace.screen(screen_path.screen_id)
        .pane(screen_path.pane_id);

    const auto correlation_key =
        key_prefix + "-terminal-correlation";
    hmux::RunOptions run(take(hmux::RunCommand::shell(
        string_field(request, "exit_shell"))));
    run.correlation_key = correlation_key;
    const auto run_result = take(pane.run(
        std::move(run),
        key(key_prefix, "terminal-run")));
    const auto& path = run_result.value;
    auto terminal = client.terminal(path.terminal_id);

    const auto pending_result = take(terminal.wait_exit(decimal(
        string_field(request, "pending_timeout_ms"))));
    const auto& pending = require_pending(pending_result);
    const auto resolution =
        take(current.resolve_creation(correlation_key));
    if (!resolution.created_path) {
        throw AdapterError("creation resolution omitted its terminal path");
    }
    const auto* resolved =
        std::get_if<hmux::CreatedTerminalPath>(
            &*resolution.created_path);
    if (!resolved ||
        resolved->workspace_id != path.workspace_id ||
        resolved->screen_id != path.screen_id ||
        resolved->pane_id != path.pane_id ||
        resolved->tab_id != path.tab_id ||
        resolved->terminal_id != path.terminal_id) {
        throw AdapterError(
            "creation resolution returned a different terminal path");
    }
    if (!resolution.generation || !resolution.revision) {
        throw AdapterError(
            "created resolution omitted generation or revision");
    }

    const auto exit_result = take(terminal.wait_exit(decimal(
        string_field(request, "exit_timeout_ms"))));
    const auto& exited = require_exited(exit_result);
    const auto& exit_code = require_exit_code(exited.outcome);
    hmux::CreatedPath created_path = path;
    return hmux::Json(hmux::Json::Object{
        {"correlation_key", hmux::Json(correlation_key)},
        {"created_path", created_path_json(created_path)},
        {"pending_terminal_id",
         hmux::Json(pending.terminal_id.value())},
        {"pending_state", hmux::Json("pending")},
        {"pending_lifecycle", hmux::Json(pending.lifecycle)},
        {"creation_state",
         hmux::Json(creation_state_name(resolution.state))},
        {"creation_recovery",
         hmux::Json(creation_recovery_name(resolution.recovery))},
        {"creation_generation", hmux::Json(*resolution.generation)},
        {"creation_revision",
         hmux::Json(std::to_string(*resolution.revision))},
        {"exit_state", hmux::Json("exited")},
        {"exit_terminal_id", hmux::Json(exited.terminal_id.value())},
        {"exit_lifecycle", hmux::Json("exited")},
        {"exit_kind", hmux::Json("exit")},
        {"exit_code", hmux::Json(std::int64_t{exit_code.code})},
        {"exited_at", hmux::Json(std::to_string(exited.exited_at))},
        {"exit_revision", hmux::Json(std::to_string(exited.revision))},
    });
}

[[nodiscard]] hmux::Json run_live_exit_restart(
    const hmux::Json& request) {
    auto client = connect(request, "current");
    auto current =
        client.session(hmux::Selector<hmux::SessionId>::current());
    const auto correlation_key =
        string_field(request, "expected_correlation_key");
    const auto resolution =
        take(current.resolve_creation(correlation_key));
    if (!resolution.created_path ||
        !resolution.generation ||
        !resolution.revision) {
        throw AdapterError(
            "durable creation resolution omitted required evidence");
    }
    const auto& expected_path = field(request, "expected_created_path");
    auto terminal = client.terminal(opaque_id<hmux::TerminalId>(
        string_field(expected_path, "terminal_id")));
    const auto exit_result = take(terminal.wait_exit(decimal(
        string_field(request, "exit_timeout_ms"))));
    const auto& exited = require_exited(exit_result);
    const auto& exit_code = require_exit_code(exited.outcome);
    return hmux::Json(hmux::Json::Object{
        {"correlation_key", hmux::Json(resolution.correlation_key)},
        {"created_path", created_path_json(*resolution.created_path)},
        {"creation_state",
         hmux::Json(creation_state_name(resolution.state))},
        {"creation_recovery",
         hmux::Json(creation_recovery_name(resolution.recovery))},
        {"creation_generation", hmux::Json(*resolution.generation)},
        {"creation_revision",
         hmux::Json(std::to_string(*resolution.revision))},
        {"exit_state", hmux::Json("exited")},
        {"exit_terminal_id", hmux::Json(exited.terminal_id.value())},
        {"exit_lifecycle", hmux::Json("exited")},
        {"exit_kind", hmux::Json("exit")},
        {"exit_code", hmux::Json(std::int64_t{exit_code.code})},
        {"exited_at", hmux::Json(std::to_string(exited.exited_at))},
        {"exit_revision", hmux::Json(std::to_string(exited.revision))},
    });
}

[[nodiscard]] hmux::Json run_live_restart(const hmux::Json& request) {
    auto client = connect(request, "current");
    auto current =
        client.session(hmux::Selector<hmux::SessionId>::current());
    const auto base = string_field(request, "workspace_name");
    const auto key_prefix = string_field(request, "key_prefix");
    const auto stable_text = string_field(request, "expected_stable_id");
    const auto duplicate_text =
        string_array_field(request, "expected_duplicate_ids");
    if (duplicate_text.size() != 2) {
        throw AdapterError(
            "expected_duplicate_ids must contain exactly two IDs");
    }
    const auto stable_id =
        opaque_id<hmux::WorkspaceId>(stable_text);
    std::vector<hmux::WorkspaceId> duplicate_ids;
    duplicate_ids.reserve(2);
    for (const auto& identifier : duplicate_text) {
        duplicate_ids.push_back(
            opaque_id<hmux::WorkspaceId>(identifier));
    }

    const auto rows = workspace_rows(current);
    const auto same_ids =
        rows.contains(stable_text) &&
        std::ranges::all_of(
            duplicate_text,
            [&rows](const auto& identifier) {
                return rows.contains(identifier);
            });
    const auto stable_name_preserved =
        rows.contains(stable_text) &&
        rows.at(stable_text) == base + "-renamed";
    const auto duplicate_name = base + "-duplicate";
    const auto duplicates_preserved =
        std::ranges::all_of(
            duplicate_text,
            [&rows, &duplicate_name](const auto& identifier) {
                const auto found = rows.find(identifier);
                return found != rows.end() &&
                       found->second == duplicate_name;
            });

    static_cast<void>(take(
        current.workspace(stable_id).close(
            key(key_prefix, "close-stable"))));
    for (std::size_t index = 0; index < duplicate_ids.size(); ++index) {
        static_cast<void>(take(
            current.workspace(duplicate_ids[index]).close(
                key(
                    key_prefix,
                    index == 0 ? "close-a" : "close-b"))));
    }
    const auto remaining = workspace_rows(current);
    const auto disappeared =
        !remaining.contains(stable_text) &&
        std::ranges::none_of(
            duplicate_text,
            [&remaining](const auto& identifier) {
                return remaining.contains(identifier);
            });

    return hmux::Json(hmux::Json::Object{
        {"same_ids", hmux::Json(same_ids)},
        {"stable_name_preserved", hmux::Json(stable_name_preserved)},
        {"duplicates_preserved", hmux::Json(duplicates_preserved)},
        {"closed", hmux::Json(true)},
        {"disappeared", hmux::Json(disappeared)},
    });
}

[[nodiscard]] hmux::Json run_live(const hmux::Json& request) {
    auto client = connect(request, "current");
    const auto available_sessions = take(client.sessions());
    if (available_sessions.empty()) {
        throw AdapterError("session.list omitted an opaque session id");
    }
    auto current_session = client.session(available_sessions.front().id);
    const auto ping = take(current_session.ping());
    const auto pinged = ping.alive;

    const auto name = string_field(request, "workspace_name");
    hmux::CreateWorkspaceOptions create;
    create.name = name;
    create.initial_content = hmux::InitialContent::empty;
    auto created = take(current_session.create_workspace(
        std::move(create),
        take(hmux::MutationOptions::with_key("live-create"))));
    const auto workspace_id = std::visit(
        [](const auto& value) { return value.workspace_id; },
        created.value);
    auto target = client.workspace(workspace_id);
    const auto renamed_result = take(target.rename(
        name + "-renamed",
        take(hmux::MutationOptions::with_key("live-rename"))));
    const auto renamed = renamed_result.value.name == name + "-renamed";
    const auto listed_workspaces = take(current_session.workspaces());
    const auto listed = std::ranges::any_of(
        listed_workspaces,
        [&workspace_id](const auto& item) {
            return item.id == workspace_id;
        });
    static_cast<void>(take(target.close(
        take(hmux::MutationOptions::with_key("live-close")))));
    const auto remaining = take(current_session.workspaces());
    const auto disappeared = std::ranges::none_of(
        remaining,
        [&workspace_id](const auto& item) {
            return item.id == workspace_id;
        });

    return hmux::Json(hmux::Json::Object{
        {"pinged", hmux::Json(pinged)},
        {"created", hmux::Json(true)},
        {"renamed", hmux::Json(renamed)},
        {"listed", hmux::Json(listed)},
        {"closed", hmux::Json(true)},
        {"disappeared", hmux::Json(disappeared)},
    });
}

[[nodiscard]] hmux::Json run(const hmux::Json& request) {
    const auto operation = string_field(request, "op");
    if (operation == "read") {
        return run_read(request);
    }
    if (operation == "mutation-replay") {
        return run_mutation_replay(request);
    }
    if (operation == "mutation-error") {
        return run_mutation_error(request);
    }
    if (operation == "creation-resolve") {
        return run_creation_resolve(request);
    }
    if (operation == "creation-conflict") {
        return run_creation_conflict(request);
    }
    if (operation == "terminal-wait-exit") {
        return run_terminal_wait_exit(request);
    }
    if (operation == "stream-unknown") {
        return run_stream_unknown(request);
    }
    if (operation == "stream-cancel") {
        return run_stream_cancel(request);
    }
    if (operation == "stream-overflow") {
        return run_stream_overflow(request);
    }
    if (operation == "redaction") {
        return run_redaction();
    }
    if (operation == "live-setup") {
        return run_live_setup(request);
    }
    if (operation == "live-creation-exit") {
        return run_live_creation_exit(request);
    }
    if (operation == "live-exit-restart") {
        return run_live_exit_restart(request);
    }
    if (operation == "live-restart") {
        return run_live_restart(request);
    }
    if (operation == "live-flow") {
        return run_live(request);
    }
    throw AdapterError("unknown adapter operation: " + operation);
}

[[nodiscard]] hmux::Json success(
    std::string identifier,
    hmux::Json value) {
    return hmux::Json(hmux::Json::Object{
        {"contract_version", hmux::Json(std::uint64_t{2})},
        {"id", hmux::Json(std::move(identifier))},
        {"ok", hmux::Json(true)},
        {"value", std::move(value)},
    });
}

[[nodiscard]] hmux::Json failure(
    std::string identifier,
    std::string message) {
    return hmux::Json(hmux::Json::Object{
        {"contract_version", hmux::Json(std::uint64_t{2})},
        {"id", hmux::Json(std::move(identifier))},
        {"ok", hmux::Json(false)},
        {"error",
         hmux::Json(hmux::Json::Object{
             {"kind", hmux::Json("adapter")},
             {"message", hmux::Json(std::move(message))},
         })},
    });
}

}  // namespace

int main() {
    std::string input;
    std::getline(std::cin, input);
    std::string identifier;
    hmux::Json response;
    try {
        const auto request = take(hmux::Json::parse(input));
        identifier = string_field(request, "id");
        response = success(identifier, run(request));
    } catch (const std::exception& error) {
        response = failure(identifier, error.what());
    }
    auto encoded = response.encode();
    if (!encoded) {
        std::cerr << describe(encoded.error()) << '\n';
        return 1;
    }
    std::cout << encoded.value() << '\n';
    return 0;
}
