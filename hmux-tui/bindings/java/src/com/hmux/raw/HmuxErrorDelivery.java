package com.hmux.raw;

public enum HmuxErrorDelivery {
    KNOWN_NOT_DELIVERED,
    AMBIGUOUS;

    static HmuxErrorDelivery fromWire(Object value) {
        if ("known-not-delivered".equals(value)) {
            return KNOWN_NOT_DELIVERED;
        }
        if ("ambiguous".equals(value)) {
            return AMBIGUOUS;
        }
        return null;
    }
}
