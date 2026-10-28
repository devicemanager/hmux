package com.hmux.raw;

import com.hmux.raw.Protocol;
import com.hmux.raw.ProtocolEvent;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicBoolean;

/** Dedicated synchronous event stream. Closing it unblocks a pending read. */
public final class HmuxStream<E extends ProtocolEvent> implements AutoCloseable {
    private final JsonLineConnection connection;
    private final Duration defaultTimeout;
    private final Class<E> eventType;
    private final ArrayDeque<ProtocolEvent> buffered;
    private final AtomicBoolean closed = new AtomicBoolean();

    private HmuxStream(
        JsonLineConnection connection,
        Duration defaultTimeout,
        Class<E> eventType,
        ArrayDeque<ProtocolEvent> buffered
    ) {
        this.connection = connection;
        this.defaultTimeout = defaultTimeout;
        this.eventType = eventType;
        this.buffered = buffered;
    }

    static <E extends ProtocolEvent> HmuxStream<E> open(
        JsonLineConnection connection,
        Duration timeout,
        Map<String, Object> request,
        Class<E> eventType,
        int maxBufferedEvents
    ) throws HmuxException {
        Objects.requireNonNull(eventType, "eventType");
        if (maxBufferedEvents < 1) {
            throw new IllegalArgumentException("maxBufferedEvents must be positive");
        }
        JsonLineConnection.Deadline deadline = JsonLineConnection.deadline(timeout);
        ArrayDeque<ProtocolEvent> buffered = new ArrayDeque<>();
        Object id = request.get("id");
        boolean attach = "attach-surface".equals(request.get("cmd"));
        try {
            connection.send(request, deadline);
            while (true) {
                Map<String, Object> message = connection.receive(deadline);
                if (message.containsKey("event")) {
                    ProtocolEvent event = Protocol.decodeEvent(message);
                    if (buffered.size() >= maxBufferedEvents) {
                        throw new HmuxStreamBufferOverflowException(maxBufferedEvents);
                    }
                    buffered.addLast(event);
                    if (attach && isInitialAttachEvent(event.event())) {
                        return new HmuxStream<>(connection, timeout, eventType, buffered);
                    }
                    continue;
                }
                if (message.containsKey("id") && !HmuxClient.idsEqual(message.get("id"), id)) {
                    continue;
                }
                if (Boolean.TRUE.equals(message.get("ok"))) {
                    return new HmuxStream<>(connection, timeout, eventType, buffered);
                }
                throw new HmuxCommandException(
                    String.valueOf(message.getOrDefault("error", "unknown error")),
                    message.get("id")
                );
            }
        } catch (HmuxException | RuntimeException error) {
            connection.close();
            throw error;
        }
    }

    public E next() throws HmuxException {
        return next(defaultTimeout);
    }

    public E next(Duration timeout) throws HmuxException {
        return next(timeout, () -> {});
    }

    E next(Duration timeout, Runnable beforeWait) throws HmuxException {
        if (closed.get()) {
            throw new HmuxTransportException("stream is closed");
        }
        ProtocolEvent event;
        if (!buffered.isEmpty()) {
            event = buffered.removeFirst();
        } else {
            JsonLineConnection.Deadline deadline = JsonLineConnection.deadline(timeout);
            while (true) {
                Map<String, Object> message = connection.receive(deadline, beforeWait);
                if (message.containsKey("event")) {
                    event = Protocol.decodeEvent(message);
                    break;
                }
            }
        }
        if (!eventType.isInstance(event)) {
            throw new HmuxDecodeException(
                "event " + event.event() + " is outside this stream mode",
                null
            );
        }
        E typed = eventType.cast(event);
        if ("overflow".equals(event.event()) || "detached".equals(event.event())) {
            close();
        }
        return typed;
    }

    public boolean isClosed() {
        return closed.get();
    }

    @Override
    public void close() {
        if (closed.compareAndSet(false, true)) {
            connection.close();
        }
    }

    private static boolean isInitialAttachEvent(String event) {
        return "vt-state".equals(event)
            || "render-state".equals(event)
            || "browser-state".equals(event);
    }
}
