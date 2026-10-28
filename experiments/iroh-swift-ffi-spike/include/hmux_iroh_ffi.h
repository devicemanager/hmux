// Minimal C FFI over iroh for the hmux mobile transport spike.
// See rust/src/lib.rs for semantics. All blocking; call off the main thread.

#ifndef HMUX_IROH_FFI_H
#define HMUX_IROH_FFI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct HmuxIrohEndpoint HmuxIrohEndpoint;
typedef struct HmuxIrohConnection HmuxIrohConnection;

HmuxIrohEndpoint *hmux_iroh_endpoint_bind(
    bool enable_relay,
    bool accept_connections,
    char *err_buf,
    size_t err_cap);

char *hmux_iroh_endpoint_id(const HmuxIrohEndpoint *endpoint);

char *hmux_iroh_endpoint_route_json(const HmuxIrohEndpoint *endpoint);

int hmux_iroh_endpoint_online(
    HmuxIrohEndpoint *endpoint,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

HmuxIrohConnection *hmux_iroh_endpoint_accept(
    HmuxIrohEndpoint *endpoint,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

HmuxIrohConnection *hmux_iroh_endpoint_connect(
    HmuxIrohEndpoint *endpoint,
    const char *endpoint_id,
    const char *relay_url,
    const char *const *direct_addrs,
    size_t direct_addr_count,
    uint64_t timeout_ms,
    char *err_buf,
    size_t err_cap);

intptr_t hmux_iroh_connection_recv(
    HmuxIrohConnection *connection,
    uint8_t *buf,
    size_t cap,
    char *err_buf,
    size_t err_cap);

int hmux_iroh_connection_send(
    HmuxIrohConnection *connection,
    const uint8_t *bytes,
    size_t len,
    char *err_buf,
    size_t err_cap);

void hmux_iroh_connection_close(HmuxIrohConnection *connection);

void hmux_iroh_endpoint_close(HmuxIrohEndpoint *endpoint);

void hmux_iroh_string_free(char *string);

#ifdef __cplusplus
}
#endif

#endif // HMUX_IROH_FFI_H
