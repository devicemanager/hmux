package com.hmux.raw;

public class HmuxException extends Exception {
    private static final long serialVersionUID = 1L;

    public HmuxException(String message) {
        super(message);
    }

    public HmuxException(String message, Throwable cause) {
        super(message, cause);
    }
}
