package com.hmux.raw;

public final class HmuxTransportException extends HmuxException {
    private static final long serialVersionUID = 1L;

    public HmuxTransportException(String message, Throwable cause) {
        super(message, cause);
    }

    public HmuxTransportException(String message) {
        super(message);
    }
}
