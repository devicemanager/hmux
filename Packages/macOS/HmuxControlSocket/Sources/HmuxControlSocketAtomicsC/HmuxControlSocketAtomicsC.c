#include "HmuxControlSocketAtomicsC.h"

void HmuxControlSocketAtomicPointerInitialize(
    HmuxControlSocketAtomicPointerStorage *storage,
    uintptr_t initialValue
) {
    atomic_init(&storage->value, initialValue);
}

uintptr_t HmuxControlSocketAtomicPointerLoadAcquire(
    const HmuxControlSocketAtomicPointerStorage *storage
) {
    return atomic_load_explicit(&storage->value, memory_order_seq_cst);
}

uintptr_t HmuxControlSocketAtomicPointerExchange(
    HmuxControlSocketAtomicPointerStorage *storage,
    uintptr_t value
) {
    return atomic_exchange_explicit(&storage->value, value, memory_order_seq_cst);
}

void HmuxControlSocketAtomicCounterInitialize(
    HmuxControlSocketAtomicCounterStorage *storage,
    uint64_t initialValue
) {
    atomic_init(&storage->value, initialValue);
}

uint64_t HmuxControlSocketAtomicCounterLoad(
    const HmuxControlSocketAtomicCounterStorage *storage
) {
    return atomic_load_explicit(&storage->value, memory_order_seq_cst);
}

void HmuxControlSocketAtomicCounterIncrement(
    HmuxControlSocketAtomicCounterStorage *storage
) {
    atomic_fetch_add_explicit(&storage->value, 1, memory_order_seq_cst);
}

void HmuxControlSocketAtomicCounterDecrement(
    HmuxControlSocketAtomicCounterStorage *storage
) {
    atomic_fetch_sub_explicit(&storage->value, 1, memory_order_seq_cst);
}
