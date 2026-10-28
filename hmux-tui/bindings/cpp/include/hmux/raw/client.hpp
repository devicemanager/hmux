#pragma once

// Low-level protocol-v12 compatibility layer. Prefer <hmux/client.hpp>.
#include "hmux/raw/attachment.hpp"
#include "hmux/raw/generated/commands.hpp"

namespace hmux::raw {

using ::hmux::Error;
using ::hmux::ErrorCode;
using ::hmux::Json;
using ::hmux::JsonLimits;
using ::hmux::Timeout;
using ::hmux::Transport;
using ::hmux::TransportFactory;
using ::hmux::TransportLimits;
using ::hmux::UnixTransport;
using ::hmux::default_socket_path;
using ::hmux::make_error;
using ::hmux::socket_path_from_environment;
using ::hmux::unix_transport_factory;

template <typename T>
using result = ::hmux::Result<T>;
template <typename T>
using Result = ::hmux::Result<T>;

}  // namespace hmux::raw
