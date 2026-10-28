#ifndef HMUX_TERMINATION_WATCHDOG_ATOMIC_H
#define HMUX_TERMINATION_WATCHDOG_ATOMIC_H

#include <stdbool.h>
#include <stdatomic.h>

typedef struct {
    atomic_bool isArmed;
} HMUXTerminationWatchdogLatch;

HMUXTerminationWatchdogLatch HMUXTerminationWatchdogLatchMake(void);
bool HMUXTerminationWatchdogLatchClaim(HMUXTerminationWatchdogLatch *latch);

#endif
