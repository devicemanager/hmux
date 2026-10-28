package com.hmux.raw;

/** The client was not configured for the authority required by a command. */
public final class HmuxAuthorityException extends HmuxException {
    private static final long serialVersionUID = 1L;

    public HmuxAuthorityException(String message) {
        super(message);
    }
}
