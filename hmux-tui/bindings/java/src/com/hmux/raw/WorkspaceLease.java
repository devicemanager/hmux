package com.hmux.raw;

import com.hmux.raw.CloseWorkspaceRequest;
import com.hmux.raw.WorkspaceMutationResult;
import java.util.Objects;

/**
 * Owns a workspace created by {@link HmuxClient#createWorkspaceLease}.
 *
 * <p>Keep the creating client open until this lease closes. A successful close
 * is sent at most once; if closing fails, a later call may retry.
 */
public final class WorkspaceLease implements AutoCloseable {
    private final HmuxClient client;
    private final WorkspaceMutationResult creation;
    private volatile boolean closed;

    WorkspaceLease(HmuxClient client, WorkspaceMutationResult creation) {
        this.client = Objects.requireNonNull(client, "client");
        this.creation = Objects.requireNonNull(creation, "creation");
    }

    public WorkspaceMutationResult creation() {
        return creation;
    }

    public UInt64 workspace() {
        return creation.workspace();
    }

    public String key() {
        return creation.key();
    }

    public boolean isClosed() {
        return closed;
    }

    /**
     * Closes the owned workspace. Calls after the first successful close are no-ops.
     */
    @Override
    public synchronized void close() throws HmuxException {
        if (closed) {
            return;
        }
        client.closeWorkspace(
            CloseWorkspaceRequest.builder()
                .workspace(creation.workspace())
                .build()
        );
        closed = true;
    }
}
