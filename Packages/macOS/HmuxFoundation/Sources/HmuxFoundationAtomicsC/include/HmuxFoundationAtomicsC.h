#ifndef HMUX_FOUNDATION_ATOMICS_C_H
#define HMUX_FOUNDATION_ATOMICS_C_H

#include <stdbool.h>
#include <stdint.h>
#include <stdatomic.h>

typedef struct {
    atomic_bool value;
} HmuxAtomicBooleanStorage;

void HmuxAtomicBooleanInitialize(HmuxAtomicBooleanStorage *storage, bool initialValue);
bool HmuxAtomicBooleanLoadRelaxed(const HmuxAtomicBooleanStorage *storage);
bool HmuxAtomicBooleanLoadAcquire(const HmuxAtomicBooleanStorage *storage);
void HmuxAtomicBooleanStoreRelease(HmuxAtomicBooleanStorage *storage, bool value);
bool HmuxAtomicBooleanCompareExchange(
    HmuxAtomicBooleanStorage *storage,
    bool expected,
    bool desired
);

typedef struct {
    _Atomic(uint64_t) value;
} HmuxAtomicUInt64Storage;

void HmuxAtomicUInt64Initialize(HmuxAtomicUInt64Storage *storage, uint64_t initialValue);
uint64_t HmuxAtomicUInt64LoadRelaxed(const HmuxAtomicUInt64Storage *storage);
void HmuxAtomicUInt64StoreRelaxed(HmuxAtomicUInt64Storage *storage, uint64_t value);
uint64_t HmuxAtomicUInt64IncrementRelaxed(HmuxAtomicUInt64Storage *storage);
uint64_t HmuxAtomicUInt64AdvanceRelaxed(HmuxAtomicUInt64Storage *storage);
bool HmuxAtomicUInt64IncrementIfBelow(
    HmuxAtomicUInt64Storage *storage,
    uint64_t upperBound
);
bool HmuxAtomicUInt64DecrementIfPositive(HmuxAtomicUInt64Storage *storage);

#endif
