#include "test.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <set>
#include <string>
#include <type_traits>
#include <utility>
#include <variant>

#include "hmux/raw/client.hpp"

static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().identify()),
              hmux::raw::Result<hmux::raw::IdentifyResult>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().subscribe_deltas()),
              hmux::raw::Result<hmux::raw::DeltaStream>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().attach_bytes(
                  std::declval<const hmux::raw::AttachSurfaceRequest&>())),
              hmux::raw::Result<hmux::raw::ByteStream>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().attach_render(
                  std::declval<const hmux::raw::AttachSurfaceRequest&>())),
              hmux::raw::Result<hmux::raw::RenderStream>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().attach_browser(
                  std::declval<const hmux::raw::AttachSurfaceRequest&>())),
              hmux::raw::Result<hmux::raw::BrowserStream>>);
static_assert(std::is_same_v<
              decltype(
                  std::declval<hmux::raw::Client&>().browser_frame_presented(
                      std::declval<
                          const hmux::raw::BrowserFramePresentedRequest&>())),
              hmux::raw::Result<hmux::raw::EmptyResult>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().browser_key_press(
                  std::declval<
                      const hmux::raw::BrowserKeyPressRequest&>())),
              hmux::raw::Result<hmux::raw::EmptyResult>>);
static_assert(std::is_same_v<
              decltype(
                  std::declval<hmux::raw::Client&>().browser_mouse_guarded(
                      std::declval<
                          const hmux::raw::BrowserMouseGuardedRequest&>())),
              hmux::raw::Result<hmux::raw::EmptyResult>>);
static_assert(std::is_same_v<
              decltype(
                  std::declval<hmux::raw::Client&>().browser_wheel_guarded(
                      std::declval<
                          const hmux::raw::BrowserWheelGuardedRequest&>())),
              hmux::raw::Result<hmux::raw::EmptyResult>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().clear_history(
                  std::declval<const hmux::raw::ClearHistoryRequest&>())),
              hmux::raw::Result<hmux::raw::EmptyResult>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().new_pane_right(
                  std::declval<const hmux::raw::NewPaneRightRequest&>())),
              hmux::raw::Result<hmux::raw::SurfaceResult>>);
static_assert(std::is_same_v<
              decltype(
                  std::declval<hmux::raw::Client&>().set_viewport_pane_width(
                      std::declval<
                          const hmux::raw::SetViewportPaneWidthRequest&>())),
              hmux::raw::Result<hmux::raw::EmptyResult>>);
static_assert(std::is_same_v<
              decltype(std::declval<hmux::raw::Client&>().undo_layout(
                  std::declval<const hmux::raw::UndoLayoutRequest&>())),
              hmux::raw::Result<hmux::raw::LayoutUndoResult>>);
static_assert(
    std::variant_size_v<hmux::raw::LayoutUndoResult::Variant> == 2U);
static_assert(std::is_same_v<
              std::variant_alternative_t<
                  0, hmux::raw::LayoutUndoResult::Variant>,
              hmux::raw::LayoutUndoUndone>);
static_assert(std::is_same_v<
              std::variant_alternative_t<
                  1, hmux::raw::LayoutUndoResult::Variant>,
              hmux::raw::LayoutUndoConfirmationRequired>);
static_assert(!std::is_copy_constructible_v<hmux::raw::EventStream>);
static_assert(std::is_move_constructible_v<hmux::raw::EventStream>);

constexpr std::size_t kExpectedRawCommandCount = 118U;
constexpr std::array<std::string_view, 4> kViewportHistoryCommandNames{
    "clear-history",
    "new-pane-right",
    "set-viewport-pane-width",
    "undo-layout",
};
constexpr std::array<std::string_view, 4> kBrowserPointerCommandNames{
    "browser-frame-presented",
    "browser-key-press",
    "browser-mouse-guarded",
    "browser-wheel-guarded",
};

TEST("generated command and event metadata is exhaustive and unique") {
    const auto commands = hmux::raw::command_metadata();
    const auto events = hmux::raw::event_metadata();
    CHECK_EQ(commands.size(), kExpectedRawCommandCount);
    CHECK_EQ(events.size(), 50U);

    std::set<std::string_view> command_names;
    bool checked_attach_fields = false;
    for (const auto& command : commands) {
        CHECK(!command.name.empty());
        CHECK(!command.authority.empty());
        CHECK(command.since <= hmux::raw::kMuxProtocolVersion);
        command_names.insert(command.name);
        if (command.name == "attach-surface") {
            CHECK_EQ(command.field_requirements.size(), 5U);
            bool mode_since = false;
            bool cols_capability = false;
            bool generation_capability = false;
            bool terminal_capability = false;
            for (const auto& field : command.field_requirements) {
                mode_since =
                    mode_since || (field.name == "mode" && field.since == 7U);
                cols_capability =
                    cols_capability ||
                    (field.name == "cols" &&
                     field.capability == "attach-initial-size");
                generation_capability =
                    generation_capability ||
                    (field.name == "expected_generation" &&
                     field.capability == "attach-identity-v1");
                terminal_capability =
                    terminal_capability ||
                    (field.name == "expected_terminal_id" &&
                     field.capability == "attach-identity-v1");
            }
            CHECK(mode_since);
            CHECK(cols_capability);
            CHECK(generation_capability);
            CHECK(terminal_capability);
            checked_attach_fields = true;
        }
    }
    CHECK_EQ(command_names.size(), commands.size());
    CHECK(checked_attach_fields);
    for (const auto name : kViewportHistoryCommandNames) {
        CHECK(command_names.contains(name));
    }
    for (const auto name : kBrowserPointerCommandNames) {
        CHECK(command_names.contains(name));
    }

    std::set<std::string_view> event_names;
    for (const auto& event : events) {
        CHECK(!event.name.empty());
        CHECK(event.since <= hmux::raw::kMuxProtocolVersion);
        event_names.insert(event.name);
    }
    CHECK_EQ(event_names.size(), events.size());
}

TEST("generated guarded browser requests preserve exact fields") {
    constexpr auto frame_seq = std::numeric_limits<std::uint64_t>::max();

    hmux::raw::BrowserFramePresentedRequest presented;
    presented.frame_seq = frame_seq;
    presented.surface = hmux::raw::Id{7};
    auto encoded_presented = hmux::raw::encode_value(presented);
    CHECK(encoded_presented);
    CHECK_EQ(
        encoded_presented.value()
            .find("frame_seq")
            ->as_uint64()
            .value(),
        frame_seq);
    auto decoded_presented =
        hmux::raw::decode_value<hmux::raw::BrowserFramePresentedRequest>(
            encoded_presented.value());
    CHECK(decoded_presented);
    CHECK_EQ(decoded_presented.value(), presented);

    hmux::raw::BrowserKeyPressRequest key;
    key.code = "KeyA";
    key.key = "a";
    key.modifiers = 3;
    key.surface = hmux::raw::Id{7};
    key.text = hmux::raw::Field<std::string>("a");
    key.windows_virtual_key_code = 65;
    auto encoded_key = hmux::raw::encode_value(key);
    CHECK(encoded_key);
    auto decoded_key =
        hmux::raw::decode_value<hmux::raw::BrowserKeyPressRequest>(
            encoded_key.value());
    CHECK(decoded_key);
    CHECK_EQ(decoded_key.value(), key);

    hmux::raw::BrowserMouseGuardedRequest mouse;
    mouse.button = hmux::raw::Field<std::string>("left");
    mouse.click_count = hmux::raw::Field<std::uint32_t>(2);
    mouse.frame_seq = frame_seq;
    mouse.kind = hmux::raw::BrowserMouseGuardedRequestKind::down;
    mouse.surface = hmux::raw::Id{7};
    mouse.x_px = 12.5;
    mouse.y_px = 34.5;
    auto encoded_mouse = hmux::raw::encode_value(mouse);
    CHECK(encoded_mouse);
    CHECK_EQ(
        encoded_mouse.value().find("frame_seq")->as_uint64().value(),
        frame_seq);
    auto decoded_mouse =
        hmux::raw::decode_value<hmux::raw::BrowserMouseGuardedRequest>(
            encoded_mouse.value());
    CHECK(decoded_mouse);
    CHECK_EQ(decoded_mouse.value(), mouse);

    hmux::raw::BrowserWheelGuardedRequest wheel;
    wheel.delta_y_px = -120.25;
    wheel.frame_seq = frame_seq;
    wheel.surface = hmux::raw::Id{7};
    wheel.x_px = 640.5;
    wheel.y_px = 360.25;
    auto encoded_wheel = hmux::raw::encode_value(wheel);
    CHECK(encoded_wheel);
    CHECK_EQ(
        encoded_wheel.value().find("frame_seq")->as_uint64().value(),
        frame_seq);
    auto decoded_wheel =
        hmux::raw::decode_value<hmux::raw::BrowserWheelGuardedRequest>(
            encoded_wheel.value());
    CHECK(decoded_wheel);
    CHECK_EQ(decoded_wheel.value(), wheel);
}

TEST("layout undo result variants round trip without losing their branch") {
    hmux::raw::LayoutUndoUndone undone;
    undone.confirmation_required = false;
    undone.revision = std::numeric_limits<std::uint64_t>::max();
    undone.screen = hmux::raw::Id{7};
    hmux::raw::LayoutUndoResult undone_result{
        hmux::raw::LayoutUndoResult::Variant(undone),
    };
    auto encoded_undone = hmux::raw::encode_value(undone_result);
    CHECK(encoded_undone);
    auto decoded_undone =
        hmux::raw::decode_value<hmux::raw::LayoutUndoResult>(
            encoded_undone.value());
    CHECK(decoded_undone);
    const auto* decoded_undone_value =
        std::get_if<hmux::raw::LayoutUndoUndone>(
            &decoded_undone.value().value);
    CHECK(decoded_undone_value != nullptr);
    CHECK_EQ(decoded_undone_value->revision, undone.revision);
    CHECK_EQ(decoded_undone_value->screen, undone.screen);

    hmux::raw::LayoutUndoConfirmationRequired confirmation;
    confirmation.closes_panes = {
        hmux::raw::Id{11},
        hmux::raw::Id{12},
    };
    confirmation.revision = 42;
    confirmation.screen = hmux::raw::Id{9};
    hmux::raw::LayoutUndoResult confirmation_result{
        hmux::raw::LayoutUndoResult::Variant(confirmation),
    };
    auto encoded_confirmation =
        hmux::raw::encode_value(confirmation_result);
    CHECK(encoded_confirmation);
    auto decoded_confirmation =
        hmux::raw::decode_value<hmux::raw::LayoutUndoResult>(
            encoded_confirmation.value());
    CHECK(decoded_confirmation);
    const auto* decoded_confirmation_value =
        std::get_if<hmux::raw::LayoutUndoConfirmationRequired>(
            &decoded_confirmation.value().value);
    CHECK(decoded_confirmation_value != nullptr);
    CHECK_EQ(
        decoded_confirmation_value->closes_panes,
        confirmation.closes_panes);
    CHECK_EQ(
        decoded_confirmation_value->revision,
        confirmation.revision);
    CHECK_EQ(decoded_confirmation_value->screen, confirmation.screen);
}

TEST("generated uint64 aliases retain values above JavaScript's safe range") {
    const hmux::raw::Id identifier{std::numeric_limits<std::uint64_t>::max()};
    auto encoded = hmux::raw::encode_value(identifier);
    CHECK(encoded);
    CHECK_EQ(
        encoded.value().as_uint64().value(),
        std::numeric_limits<std::uint64_t>::max());
    auto decoded = hmux::raw::decode_value<hmux::raw::Id>(encoded.value());
    CHECK(decoded);
    CHECK_EQ(decoded.value(), identifier);
}

TEST("generated optional nullable request fields preserve absent and null") {
    hmux::raw::SetDefaultColorsRequest request;
    auto absent = hmux::raw::encode_value(request);
    CHECK(absent);
    CHECK(absent.value().find("fg") == nullptr);

    request.fg = hmux::raw::Field<hmux::raw::ColorHex>::null();
    auto explicit_null = hmux::raw::encode_value(request);
    CHECK(explicit_null);
    CHECK(explicit_null.value().find("fg") != nullptr);
    CHECK(explicit_null.value().find("fg")->is_null());
}

TEST("terminal placement rejects legacy shapes and round trips typed lifecycle") {
    auto legacy = hmux::raw::Json::parse(
        R"({"surface":1,"terminal_id":null,"terminal_incarnation":null,"pane":2,"screen":3,"workspace":4,"key":"legacy","lifecycle":null,"terminal_revision":5,"replayed":false,"registry_id":"registry","generation":"boot"})");
    CHECK(legacy);
    auto legacy_placement =
        hmux::raw::decode_value<hmux::raw::TerminalPlacement>(legacy.value());
    CHECK(!legacy_placement);
    CHECK_EQ(legacy_placement.error().code, hmux::raw::ErrorCode::decode);

    auto current = hmux::raw::Json::parse(
        R"({"already_exited":false,"exit":null,"surface":1,"terminal_id":"terminal","terminal_incarnation":"incarnation","pane":2,"screen":3,"workspace":4,"key":"current","lifecycle":"running","terminal_revision":6,"replayed":true,"registry_id":"registry","generation":"boot"})");
    CHECK(current);
    auto current_placement =
        hmux::raw::decode_value<hmux::raw::TerminalPlacement>(current.value());
    CHECK(current_placement);
    CHECK_EQ(
        current_placement.value().lifecycle,
        hmux::raw::TerminalLifecycle::running);
    auto current_round_trip = hmux::raw::encode_value(current_placement.value());
    CHECK(current_round_trip);
    CHECK(current_round_trip.value().find("exit")->is_null());
    CHECK_EQ(
        current_round_trip.value().find("lifecycle")->as_string().value(),
        std::string_view("running"));

    current_placement.value().lifecycle =
        static_cast<hmux::raw::TerminalLifecycle>(999);
    auto invalid = hmux::raw::encode_value(current_placement.value());
    CHECK(!invalid);
    CHECK_EQ(invalid.error().code, hmux::raw::ErrorCode::invalid_argument);
}

TEST("known events decode to typed variants") {
    auto wire = hmux::raw::Json::parse(R"({"event":"config-reload-requested"})");
    CHECK(wire);
    auto event = hmux::raw::decode_value<hmux::raw::Event>(wire.value());
    CHECK(event);
    CHECK(std::holds_alternative<hmux::raw::ConfigReloadRequestedEvent>(event.value().value));
    CHECK_EQ(event.value().name(), std::string_view("config-reload-requested"));
}

TEST("unknown events retain their name and entire JSON object") {
    auto wire = hmux::raw::Json::parse(
        R"({"event":"future-protocol-event","id":18446744073709551615,"nested":{"x":1}})");
    CHECK(wire);
    auto event = hmux::raw::decode_value<hmux::raw::Event>(wire.value());
    CHECK(event);
    const auto* unknown = std::get_if<hmux::raw::UnknownEvent>(&event.value().value);
    CHECK(unknown != nullptr);
    CHECK_EQ(unknown->name, std::string("future-protocol-event"));
    CHECK_EQ(unknown->raw, wire.value());
    auto encoded = hmux::raw::encode_value(event.value());
    CHECK(encoded);
    CHECK_EQ(encoded.value(), wire.value());
}

TEST("recursive tagged layout models round trip through shared ownership") {
    hmux::raw::LayoutSplit split;
    split.dir = hmux::raw::SplitDirection::right;
    split.ratio = 0.5F;
    split.a = std::make_shared<hmux::raw::Layout>(
        hmux::raw::Layout{hmux::raw::Layout::Variant(hmux::raw::LayoutLeaf{hmux::raw::Id{1}})});
    split.b = std::make_shared<hmux::raw::Layout>(
        hmux::raw::Layout{hmux::raw::Layout::Variant(
            hmux::raw::LayoutStack{hmux::raw::Id{2}, {hmux::raw::Id{2}, hmux::raw::Id{3}}})});
    hmux::raw::Layout layout{hmux::raw::Layout::Variant(std::move(split))};
    auto encoded = hmux::raw::encode_value(layout);
    CHECK(encoded);
    auto decoded = hmux::raw::decode_value<hmux::raw::Layout>(encoded.value());
    CHECK(decoded);
    CHECK(std::holds_alternative<hmux::raw::LayoutSplit>(decoded.value().value));
}
