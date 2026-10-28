#ifndef unix
#define unix 0x434d5558
#endif

constexpr auto kUnixMacroBeforeHmuxInclude = unix;

#include "hmux/client.hpp"
#include "hmux/raw/client.hpp"
#include "test.hpp"

#ifndef unix
#error "hmux headers must preserve the caller's unix macro"
#endif

static_assert(unix == kUnixMacroBeforeHmuxInclude);

TEST("public and generated enums survive caller macros and preserve wire values") {
    hmux::ClientSnapshot snapshot;
    CHECK_EQ(snapshot.transport, hmux::ClientTransport::unix_socket);

    auto wire = hmux::raw::Json::parse(R"("unix")");
    CHECK(wire);

    auto decoded = hmux::raw::decode_value<hmux::raw::ClientTransport>(wire.value());
    CHECK(decoded);
    CHECK_EQ(decoded.value(), hmux::raw::ClientTransport::unix_);

    auto encoded = hmux::raw::encode_value(decoded.value());
    CHECK(encoded);
    CHECK_EQ(encoded.value().as_string().value(), std::string_view("unix"));
    CHECK_EQ(unix, kUnixMacroBeforeHmuxInclude);
}
