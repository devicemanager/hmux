#ifndef HMUX_CONTROL_SOCKET_ATOMICS_C_H
#define HMUX_CONTROL_SOCKET_ATOMICS_C_H

#include <stdint.h>
#include <stdatomic.h>

typedef struct {
    _Atomic(uintptr_t) value;
} HmuxControlSocketAtomicPointerStorage;

void HmuxControlSocketAtomicPointerInitialize(
    HmuxControlSocketAtomicPointerStorage *storage,
    uintptr_t initialValue
);
uintptr_t HmuxControlSocketAtomicPointerLoadAcquire(
    const HmuxControlSocketAtomicPointerStorage *storage
);
uintptr_t HmuxControlSocketAtomicPointerExchange(
    HmuxControlSocketAtomicPointerStorage *storage,
    uintptr_t value
);

typedef struct {
    _Atomic(uint64_t) value;
} HmuxControlSocketAtomicCounterStorage;

void HmuxControlSocketAtomicCounterInitialize(
    HmuxControlSocketAtomicCounterStorage *storage,
    uint64_t initialValue
);
uint64_t HmuxControlSocketAtomicCounterLoad(
    const HmuxControlSocketAtomicCounterStorage *storage
);
void HmuxControlSocketAtomicCounterIncrement(
    HmuxControlSocketAtomicCounterStorage *storage
);
void HmuxControlSocketAtomicCounterDecrement(
    HmuxControlSocketAtomicCounterStorage *storage
);

#endif
