#include "include/WattcherSystem.h"

#include <libproc.h>
#include <string.h>
#include <sys/proc_info.h>
#include <sys/resource.h>

int wattcher_read_process(
    int32_t pid,
    char *path,
    int32_t path_capacity,
    uint32_t *user_id,
    uint64_t *start_time_microseconds,
    uint64_t *cpu_time_nanoseconds,
    uint64_t *resident_bytes,
    uint64_t *wakeups
) {
    if (pid <= 0 || path == NULL || path_capacity <= 0) {
        return -1;
    }

    memset(path, 0, (size_t)path_capacity);
    if (proc_pidpath(pid, path, (uint32_t)path_capacity) <= 0) {
        return -1;
    }

    struct proc_bsdinfo bsd = {0};
    int bsd_size = proc_pidinfo(
        pid,
        PROC_PIDTBSDINFO,
        0,
        &bsd,
        (int)sizeof(bsd)
    );
    if (bsd_size != (int)sizeof(bsd)) {
        return -1;
    }

    struct proc_taskinfo task = {0};
    int task_size = proc_pidinfo(
        pid,
        PROC_PIDTASKINFO,
        0,
        &task,
        (int)sizeof(task)
    );
    if (task_size != (int)sizeof(task)) {
        return -1;
    }

    struct rusage_info_v6 usage = {0};
    int usage_result = proc_pid_rusage(
        pid,
        RUSAGE_INFO_V6,
        (rusage_info_t *)&usage
    );

    *user_id = bsd.pbi_uid;
    *start_time_microseconds = (uint64_t)bsd.pbi_start_tvsec * 1000000
        + (uint64_t)bsd.pbi_start_tvusec;
    *cpu_time_nanoseconds = task.pti_total_user + task.pti_total_system;
    *resident_bytes = task.pti_resident_size;
    *wakeups = usage_result == 0
        ? usage.ri_pkg_idle_wkups + usage.ri_interrupt_wkups
        : 0;
    return 0;
}
