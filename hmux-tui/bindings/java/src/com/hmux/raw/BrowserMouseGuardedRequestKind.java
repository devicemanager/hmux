// Generated from hmux-tui/spec/sdk-schema.json. DO NOT EDIT.
package com.hmux.raw;

import java.util.Objects;

public enum BrowserMouseGuardedRequestKind implements WireEnum {
    DOWN("down"),
    UP("up"),
    MOVE("move");

    private final Object wireValue;

    BrowserMouseGuardedRequestKind(Object wireValue) {
        this.wireValue = wireValue;
    }

    @Override
    public String wireValue() {
        return String.valueOf(wireValue);
    }

    public Object rawWireValue() {
        return wireValue;
    }

    public static BrowserMouseGuardedRequestKind fromWire(Object value) {
        for (BrowserMouseGuardedRequestKind candidate : values()) {
            if (Objects.equals(candidate.wireValue, value)
                    || Objects.equals(String.valueOf(candidate.wireValue), value)) {
                return candidate;
            }
        }
        throw new HmuxDecodeException("unknown BrowserMouseGuardedRequestKind value " + value, null);
    }
}
