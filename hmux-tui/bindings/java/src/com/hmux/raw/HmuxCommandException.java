package com.hmux.raw;

public final class HmuxCommandException extends HmuxException {
    private static final long serialVersionUID = 1L;
    private final String serverMessage;
    @SuppressWarnings("serial")
    private final Object commandId;
    private final String errorCode;
    private final HmuxErrorDelivery errorDelivery;

    public HmuxCommandException(String serverMessage, Object commandId) {
        this(serverMessage, commandId, null, null);
    }

    public HmuxCommandException(
        String serverMessage,
        Object commandId,
        HmuxErrorDelivery errorDelivery
    ) {
        this(serverMessage, commandId, null, errorDelivery);
    }

    public HmuxCommandException(
        String serverMessage,
        Object commandId,
        String errorCode,
        HmuxErrorDelivery errorDelivery
    ) {
        super(serverMessage);
        this.serverMessage = serverMessage;
        this.commandId = commandId;
        this.errorCode = errorCode;
        this.errorDelivery = errorDelivery;
    }

    public String serverMessage() {
        return serverMessage;
    }

    public Object commandId() {
        return commandId;
    }

    public String errorCode() {
        return errorCode;
    }

    public HmuxErrorDelivery errorDelivery() {
        return errorDelivery;
    }
}
