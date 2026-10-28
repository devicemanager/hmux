const std = @import("std");
const hmux = @import("hmux_tui");

fn requirePublicDecl(
    comptime Container: type,
    comptime name: []const u8,
) void {
    if (!@hasDecl(Container, name)) {
        @compileError(std.fmt.comptimePrint(
            "{s} must expose {s}",
            .{ @typeName(Container), name },
        ));
    }
}

fn rejectPublicDecl(
    comptime Container: type,
    comptime name: []const u8,
) void {
    if (@hasDecl(Container, name)) {
        @compileError(std.fmt.comptimePrint(
            "{s} must not expose {s}",
            .{ @typeName(Container), name },
        ));
    }
}

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var client = try hmux.Client.connect(allocator, .{});
    defer client.deinit();

    var machines = try client.machines();
    defer machines.deinit();
    for (machines.items) |machine| {
        std.debug.print(
            "{s}\t{s}\t{s}\n",
            .{
                machine.id.slice(),
                machine.name,
                machine.status.wireName(),
            },
        );
    }
}

test "package consumer imports handwritten root and generated raw module" {
    comptime {
        requirePublicDecl(hmux.Machine, "listSessions");
        rejectPublicDecl(hmux.Machine, "close");
        rejectPublicDecl(hmux.Machine, "rename");
        requirePublicDecl(hmux.Session, "createWorkspace");
        requirePublicDecl(hmux.Session, "terminal");
        rejectPublicDecl(hmux.Session, "navigate");
        requirePublicDecl(hmux.Workspace, "run");
        rejectPublicDecl(hmux.Workspace, "terminal");
        rejectPublicDecl(hmux.Workspace, "sendKeys");
        requirePublicDecl(hmux.Screen, "undoLayout");
        rejectPublicDecl(hmux.Screen, "run");
        requirePublicDecl(hmux.Pane, "splitPane");
        rejectPublicDecl(hmux.Pane, "navigate");
        requirePublicDecl(hmux.Tab, "moveTab");
        rejectPublicDecl(hmux.Tab, "run");
        requirePublicDecl(hmux.Terminal, "waitForExit");
        rejectPublicDecl(hmux.Terminal, "resizeTerminalViewer");
        rejectPublicDecl(hmux.Terminal, "navigate");
        requirePublicDecl(hmux.Browser, "navigate");
        rejectPublicDecl(hmux.Browser, "readScreen");
        rejectPublicDecl(hmux.PairingRequest, "refresh");
        requirePublicDecl(
            hmux.TerminalAttachmentStream,
            "resizeTerminalViewer",
        );
        rejectPublicDecl(
            hmux.TerminalAttachmentStream,
            "resizeBrowserViewer",
        );
        requirePublicDecl(
            hmux.BrowserAttachmentStream,
            "resizeBrowserViewer",
        );
        rejectPublicDecl(
            hmux.BrowserAttachmentStream,
            "resizeTerminalViewer",
        );
        rejectPublicDecl(
            hmux.SessionEventStream,
            "resizeTerminalViewer",
        );
        rejectPublicDecl(hmux, "Notification");
        rejectPublicDecl(hmux, "Agent");
    }

    const workspace = try hmux.WorkspaceId.parse(
        "ws_0123456789abcdef0123456789abcdef",
    );
    var selector = hmux.Selector(hmux.WorkspaceId){ .name = "current" };
    const encoded = try selector.formatAlloc(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualStrings("name:current", encoded);
    try std.testing.expectEqualStrings(
        "ws_0123456789abcdef0123456789abcdef",
        workspace.slice(),
    );
    const pointer_frame_seq = std.math.maxInt(u64);
    const mouse = hmux.BrowserMouseOptions{
        .kind = .move,
        .x_px = 12,
        .y_px = 34,
        .pointer_frame_seq = pointer_frame_seq,
    };
    const wheel = hmux.BrowserWheelOptions{
        .delta_x = 0,
        .delta_y = 1,
        .pointer_frame_seq = pointer_frame_seq,
    };
    try std.testing.expectEqual(
        pointer_frame_seq,
        mouse.pointer_frame_seq,
    );
    try std.testing.expectEqual(
        pointer_frame_seq,
        wheel.pointer_frame_seq,
    );
    try std.testing.expectEqual(
        @as(usize, 118),
        hmux.raw.protocol.command_count,
    );
    try std.testing.expectEqual(
        @as(usize, 50),
        hmux.raw.protocol.event_count,
    );
    try std.testing.expect(
        @hasDecl(hmux.Client, "listMachines"),
    );
    try std.testing.expect(
        @hasDecl(hmux.Machine, "listSessions"),
    );
    try std.testing.expect(
        @hasDecl(hmux.Session, "listWorkspaces"),
    );
    try std.testing.expect(@hasDecl(hmux.Terminal, "readScreen"));
    try std.testing.expect(@hasDecl(hmux.Terminal, "readState"));
    try std.testing.expect(@hasDecl(hmux.Terminal, "readHistory"));
    try std.testing.expect(@hasDecl(hmux.Terminal, "processInfo"));
    try std.testing.expect(@hasDecl(hmux, "TerminalScreenResult"));
    try std.testing.expect(@hasDecl(hmux, "UndoLayoutOptions"));
    try std.testing.expect(
        @hasDecl(hmux, "MutationTransportUncertain"),
    );
    try std.testing.expect(
        @hasDecl(hmux.Client, "takeMutationTransportUncertain"),
    );
    try std.testing.expect(!@hasDecl(hmux, "MutationResult"));
    try std.testing.expect(!@hasDecl(hmux, "OwnedResult"));

    // Handle construction stores selectors and routes without touching the
    // client, so an external consumer can compose a route before connecting.
    var offline_client: hmux.Client = undefined;
    const terminal = offline_client
        .machine(.current)
        .session(.{ .name = "main" })
        .workspace(.{ .name = "sdk" })
        .screen(.current)
        .pane(.current)
        .tab(.current)
        .terminal(.{ .name = "shell" });
    try std.testing.expect(terminal.id() == null);

    const terminal_id = try hmux.TerminalId.parse(
        "term_0123456789abcdef0123456789abcdef",
    );
    const grant = try hmux.RendererGrant.init(std.testing.allocator, .{
        .endpoint = "/tmp/hmux-renderer.sock",
        .terminal_id = terminal_id,
        .token = .{ .bytes = "secret" },
        .rights = &.{ "read", "input" },
        .ttl_ms = 5_000,
    });
    defer grant.deinit();
    try std.testing.expectEqualStrings(
        "/tmp/hmux-renderer.sock",
        grant.endpoint(),
    );
}
