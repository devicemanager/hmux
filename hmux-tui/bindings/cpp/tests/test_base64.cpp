#include "test.hpp"

#include <array>
#include <cstddef>
#include <string>

#include "hmux/base64.hpp"

TEST("base64 codec round trips binary payloads") {
    const std::array input{
        std::byte{0x00}, std::byte{0x01}, std::byte{0xfe}, std::byte{0xff}, std::byte{0x42}};
    const auto encoded = hmux::base64_encode(input);
    CHECK_EQ(encoded, std::string("AAH+/0I="));
    auto decoded = hmux::base64_decode(encoded);
    CHECK(decoded);
    CHECK_EQ(decoded.value().size(), input.size());
    CHECK(std::equal(decoded.value().begin(), decoded.value().end(), input.begin()));
}

TEST("base64 decoder rejects malformed and oversized input") {
    CHECK(!hmux::base64_decode("abc"));
    CHECK(!hmux::base64_decode("!!!!"));
    CHECK(!hmux::base64_decode("AAAA", 2));
    CHECK(!hmux::base64_decode("A=AA"));
    CHECK(!hmux::base64_decode("AB=="));
    CHECK(!hmux::base64_decode("AAB="));
}
