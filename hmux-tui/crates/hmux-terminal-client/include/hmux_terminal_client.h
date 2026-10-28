#ifndef HMUX_TERMINAL_CLIENT_H
#define HMUX_TERMINAL_CLIENT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct HmuxTerminalClient HmuxTerminalClient;
typedef struct HmuxWireGuardNet HmuxWireGuardNet;
typedef void (*HmuxTerminalClientUpdateCallback)(void *context);
// Raw terminal output for an embedding renderer. kind is one of the
// HMUX_TERMINAL_OUTPUT_* values below. For SNAPSHOT, bytes are the replay to
// feed a fresh parser sized cols x rows. For OUTPUT, bytes are live VT output.
// RESIZED carries cols and rows only. EXIT carries nothing. bytes is valid
// only for the duration of the call.
typedef void (*HmuxTerminalClientOutputCallback)(
    void *context,
    uint32_t kind,
    const uint8_t *bytes,
    size_t length,
    uint16_t cols,
    uint16_t rows);
#define HMUX_TERMINAL_OUTPUT_SNAPSHOT 1u
#define HMUX_TERMINAL_OUTPUT_OUTPUT 2u
#define HMUX_TERMINAL_OUTPUT_RESIZED 3u
#define HMUX_TERMINAL_OUTPUT_EXIT 4u

// Both connect functions return an owned client, or NULL on failure. The caller
// transfers that ownership exactly once to hmux_terminal_client_disconnect and
// must not use the pointer after disconnect begins. invitation_uri and
// terminal_id must be non-null NUL-terminated UTF-8 strings. error_buffer may
// be NULL; when non-null with nonzero capacity it receives a truncated, valid
// UTF-8, NUL-terminated error.
HmuxTerminalClient *hmux_terminal_client_connect(
    const char *invitation_uri,
    const char *terminal_id,
    char *error_buffer,
    size_t error_capacity);
HmuxTerminalClient *hmux_terminal_client_connect_with_timeout(
    const char *invitation_uri,
    const char *terminal_id,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
// Connects by route with a persistent device identity and no terminal
// attached. route is ws://, wss://, or iroh://. state_dir holds this device's
// key and its enrolled daemons (created 0700 when missing). invitation_uri
// enrolls on first contact and may be NULL afterwards, when the enrolled key is
// used; a NULL invitation with no enrolled daemon for the route fails.
// wireguard may be NULL; when set, addresses inside that tunnel's routes are
// dialed through it. timeout_milliseconds of 0 means no deadline. Install an
// output callback, then attach a terminal.
HmuxTerminalClient *hmux_terminal_client_connect_route(
    const char *route,
    const char *state_dir,
    const char *device_name,
    const char *invitation_uri,
    const HmuxWireGuardNet *wireguard,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
// Explicit opt-in from the authenticated Cloud API: authenticate through the
// private WireGuard tunnel without an invitation. wireguard MUST be non-null;
// route MUST be a ws/wss literal IP covered by that tunnel's AllowedIPs.
// It never falls back to an ordinary OS connection. Other ownership/error
// contracts are identical to hmux_terminal_client_connect_route.
HmuxTerminalClient *hmux_terminal_client_connect_trusted_route(
    const char *route,
    const char *state_dir,
    const char *device_name,
    const HmuxWireGuardNet *wireguard,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
// Both attach functions attach the requested terminal on an existing client.
// Reattaching the same terminal is a no-op. Attaching a different terminal
// requires detach first. error_buffer follows the connect buffer contract.
bool hmux_terminal_client_attach(
    HmuxTerminalClient *client,
    const char *terminal_id,
    char *error_buffer,
    size_t error_capacity);
bool hmux_terminal_client_attach_with_timeout(
    HmuxTerminalClient *client,
    const char *terminal_id,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
// Stops the terminal stream while retaining the enrolled transport.
void hmux_terminal_client_detach(HmuxTerminalClient *client);
// Passing NULL clears the callback synchronously. The callback may run during
// registration and later on internal worker threads; calls are serialized.
// macOS callers must hop to the main actor before touching UI state. An
// invocation already in progress may overlap the start of disconnect, which
// waits for it and clears the registration before returning. context must
// remain valid until that clearing call or disconnect returns. The callback
// must not call this API because registration is locked during invocation.
void hmux_terminal_client_set_update_callback(
    HmuxTerminalClient *client,
    HmuxTerminalClientUpdateCallback callback,
    void *context);
// Installs the raw output callback, or clears it with NULL. Install it before
// attaching: the delivery mode is fixed when an attach begins, and a client
// attached without a callback keeps decoding text frames locally until it is
// detached and attached again. While a callback is installed the frame copy
// functions below return empty frames. The callback runs on internal worker
// threads, and the registration is held across the invocation so that
// clearing it waits for an in-flight call and context can then be released:
// the callback must therefore NOT call this function (doing so deadlocks on
// the registration itself). Clear the callback from another thread, or
// disconnect. context must remain valid until the clearing call or
// disconnect returns.
void hmux_terminal_client_set_output_callback(
    HmuxTerminalClient *client,
    HmuxTerminalClientOutputCallback callback,
    void *context);
// Asks for viewer-size priority on the next attach: while this client is
// attached, the terminal grid follows its reported size instead of the
// smallest size among all attached viewers, and other viewers (a Mac showing
// the same terminal) crop or pan. Like the output callback's delivery mode,
// the choice is read when an attach begins and holds for that attachment and
// its automatic reconnects; to change it for the attached terminal, detach and
// attach again. A daemon or terminal host that predates priority keeps the
// smallest-viewer behavior without failing the attach. Returns false only for a
// NULL client.
bool hmux_terminal_client_set_viewer_size_priority(HmuxTerminalClient *client, bool preferred);
// Stops all work and frees client. The pointer must not be used afterward.
void hmux_terminal_client_disconnect(HmuxTerminalClient *client);

// Starts an in-process WireGuard tunnel from wg-quick config text that carries
// PrivateKey. Keys stay in memory. The tunnel may back any number of clients
// and stays up until hmux_wireguard_net_free, which must run only after every
// client that used it has been disconnected. Returns NULL on failure with the
// error written to error_buffer.
HmuxWireGuardNet *hmux_wireguard_net_start(
    const char *config,
    char *error_buffer,
    size_t error_capacity);
// Validates a trusted-carrier route without dialing. The route must be a
// literal ws:// or wss:// IP covered by this tunnel's AllowedIPs. Returns
// false and writes the reason when the route is outside the tunnel or invalid.
bool hmux_wireguard_net_route_is_allowed(
    const HmuxWireGuardNet *net,
    const char *route,
    char *error_buffer,
    size_t error_capacity);
void hmux_wireguard_net_free(HmuxWireGuardNet *net);

// Terminal catalog over the daemon's mux control service. Both return an owned
// NUL-terminated UTF-8 JSON string to release with
// hmux_terminal_client_string_free, or NULL with the error written.
// list returns the terminal.list result array. create runs workspace.create
// with initial_content "terminal" and returns the mutation result
// (MutationResult<CreatedPath>), whose value.terminal_id is the id to attach. name may be NULL. A timeout of 0 means
// no deadline.
char *hmux_terminal_client_list_terminals(
    HmuxTerminalClient *client,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
// Returns the daemon's public session snapshot (session.snapshot: workspaces,
// screens, panes, tabs, terminals, and the rest of the session) as an owned
// UTF-8 JSON string to release with hmux_terminal_client_string_free, or NULL
// with the error written. A terminal's tab_id -> tab.pane_id ->
// pane.screen_id -> screen.workspace_id places it under its workspace, which
// terminal.list alone cannot. A timeout of 0 means no deadline.
char *hmux_terminal_client_session_snapshot(
    HmuxTerminalClient *client,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
char *hmux_terminal_client_create_terminal(
    HmuxTerminalClient *client,
    const char *name,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
// Creates a terminal tab inside an existing workspace (tab.create_terminal
// with only the workspace selector) and returns the mutation result
// (MutationResult<CreatedTerminalPath>), whose value.terminal_id is the id to
// attach. The daemon adds the tab to the workspace's focused pane (the active
// pane of its active screen) and selects it there; a workspace with no screen
// gets a new screen and pane. The session's focused workspace does not change.
// workspace_id must be an opaque ws_ id; a name or "current" is rejected before
// any request is sent. name may be NULL. Returns an owned string to release
// with hmux_terminal_client_string_free, or NULL with the error written. A
// timeout of 0 means no deadline.
char *hmux_terminal_client_create_terminal_in_workspace(
    HmuxTerminalClient *client,
    const char *workspace_id,
    const char *name,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
char *hmux_terminal_client_list_workspaces(
    HmuxTerminalClient *client,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
char *hmux_terminal_client_create_workspace(
    HmuxTerminalClient *client,
    const char *name,
    char *error_buffer,
    size_t error_capacity,
    uint64_t timeout_milliseconds);
void hmux_terminal_client_string_free(char *text);

// Input functions copy their input before returning. A false result means the
// command was not accepted by the local client queue. send_key needs the local
// parser and returns false while an output callback is installed; encode keys
// in the embedding renderer and use send instead.
bool hmux_terminal_client_send(
    HmuxTerminalClient *client,
    const uint8_t *bytes,
    size_t length);
bool hmux_terminal_client_send_key(
    HmuxTerminalClient *client,
    const char *chord,
    bool repeat);
bool hmux_terminal_client_paste(
    HmuxTerminalClient *client,
    const uint8_t *bytes,
    size_t length);
// Resize requests are coalesced to the newest geometry and delivered when the
// transport is writable. A false result means no live terminal is attached.
bool hmux_terminal_client_resize(HmuxTerminalClient *client, uint16_t cols, uint16_t rows);
// The request-ID form has the same delivery semantics and writes the nonzero
// protocol request ID when it accepts the resize. request_id must be non-null.
bool hmux_terminal_client_resize_with_request_id(
    HmuxTerminalClient *client,
    uint16_t cols,
    uint16_t rows,
    uint64_t *request_id);
// Returns false until a resize is acknowledged. All output pointers must be
// non-null and writable. A newer call replaces the prior acknowledged values.
bool hmux_terminal_client_last_resize_ack(
    const HmuxTerminalClient *client,
    uint64_t *request_id,
    uint16_t *cols,
    uint16_t *rows,
    bool *canonical_changed);

// The producer owns the snapshot and may change it between calls. Callers must
// bound two-pass retries and treat a returned length >= capacity as a truncated
// snapshot. Returned pointers are never borrowed from client storage.
#define HMUX_TERMINAL_CLIENT_COPY_MAX_BYTES (16u * 1024u * 1024u)
size_t hmux_terminal_client_copy_frame(
    const HmuxTerminalClient *client,
    char *buffer,
    size_t capacity);
// Returns the number of changed viewport rows in the latest frame. Passing a
// null buffer or insufficient capacity returns the required entry count.
size_t hmux_terminal_client_copy_frame_dirty_rows(
    const HmuxTerminalClient *client,
    uint16_t *buffer,
    size_t capacity);
size_t hmux_terminal_client_frame_row_count(const HmuxTerminalClient *client);
// Copies one zero-based viewport row from the latest frame.
size_t hmux_terminal_client_copy_frame_row(
    const HmuxTerminalClient *client,
    uint16_t row,
    char *buffer,
    size_t capacity);
size_t hmux_terminal_client_copy_diagnostics(
    const HmuxTerminalClient *client,
    char *buffer,
    size_t capacity);
bool hmux_terminal_client_has_exited(const HmuxTerminalClient *client);

#ifdef __cplusplus
}
#endif

#endif
