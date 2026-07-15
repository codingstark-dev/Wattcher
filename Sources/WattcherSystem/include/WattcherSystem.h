#ifndef WATTCHER_SYSTEM_H
#define WATTCHER_SYSTEM_H

#include <stdint.h>

int wattcher_read_process(
    int32_t pid,
    char *path,
    int32_t path_capacity,
    uint32_t *user_id,
    uint64_t *start_time_microseconds,
    uint64_t *cpu_time_nanoseconds,
    uint64_t *resident_bytes,
    uint64_t *wakeups
);

#endif
