#include "HmuxFoundationAtomicsC.h"

void HmuxAtomicBooleanInitialize(HmuxAtomicBooleanStorage *storage, bool initialValue) {
    atomic_init(&storage->value, initialValue);
}

bool HmuxAtomicBooleanLoadRelaxed(const HmuxAtomicBooleanStorage *storage) {
    return atomic_load_explicit(&storage->value, memory_order_relaxed);
}

bool HmuxAtomicBooleanLoadAcquire(const HmuxAtomicBooleanStorage *storage) {
    return atomic_load_explicit(&storage->value, memory_order_acquire);
}

void HmuxAtomicBooleanStoreRelease(HmuxAtomicBooleanStorage *storage, bool value) {
    atomic_store_explicit(&storage->value, value, memory_order_release);
}

bool HmuxAtomicBooleanCompareExchange(
    HmuxAtomicBooleanStorage *storage,
    bool expected,
    bool desired
) {
    return atomic_compare_exchange_strong_explicit(
        &storage->value,
        &expected,
        desired,
        memory_order_acq_rel,
        memory_order_acquire);
}

void HmuxAtomicUInt64Initialize(HmuxAtomicUInt64Storage *storage, uint64_t initialValue) {
    atomic_init(&storage->value, initialValue);
}

uint64_t HmuxAtomicUInt64LoadRelaxed(const HmuxAtomicUInt64Storage *storage) {
    return atomic_load_explicit(&storage->value, memory_order_relaxed);
}

void HmuxAtomicUInt64StoreRelaxed(HmuxAtomicUInt64Storage *storage, uint64_t value) {
    atomic_store_explicit(&storage->value, value, memory_order_relaxed);
}

uint64_t HmuxAtomicUInt64IncrementRelaxed(HmuxAtomicUInt64Storage *storage) {
    return atomic_fetch_add_explicit(&storage->value, 1, memory_order_relaxed) + 1;
}

uint64_t HmuxAtomicUInt64AdvanceRelaxed(HmuxAtomicUInt64Storage *storage) {
    uint64_t current = atomic_load_explicit(&storage->value, memory_order_relaxed);
    while (current != UINT64_MAX) {
        uint64_t next = current + 1;
        if (atomic_compare_exchange_weak_explicit(
                &storage->value,
                &current,
                next,
                memory_order_relaxed,
                memory_order_relaxed)) {
            return next;
        }
    }
    return UINT64_MAX;
}

bool HmuxAtomicUInt64IncrementIfBelow(
    HmuxAtomicUInt64Storage *storage,
    uint64_t upperBound
) {
    uint64_t current = atomic_load_explicit(&storage->value, memory_order_relaxed);
    while (current < upperBound) {
        if (atomic_compare_exchange_weak_explicit(
                &storage->value,
                &current,
                current + 1,
                memory_order_acq_rel,
                memory_order_acquire)) {
            return true;
        }
    }
    return false;
}

bool HmuxAtomicUInt64DecrementIfPositive(HmuxAtomicUInt64Storage *storage) {
    uint64_t current = atomic_load_explicit(&storage->value, memory_order_relaxed);
    while (current > 0) {
        if (atomic_compare_exchange_weak_explicit(
                &storage->value,
                &current,
                current - 1,
                memory_order_acq_rel,
                memory_order_acquire)) {
            return true;
        }
    }
    return false;
}
