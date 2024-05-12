/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#pragma once
#include "ockl.h"

#define TSAN_SHADOW 3

#define SHADOW_WORDS_LEVEL 3 /* 8 shadow words */

#define SHADOW_GRANULARITY (1ULL << TSAN_SHADOW)

#define GET_CALLER_PC() (uptr) __builtin_return_address(0)

#define WORKGROUP_ID(dim) __builtin_amdgcn_workgroup_id_##dim()

#define USED __attribute__((used))

#define NO_INLINE __attribute__((noinline))

#define NO_SANITIZE_THREAD __attribute__((no_sanitize("thread")))


// TODO: Make TSan report
#define REPORT_IMPL(caller_pc, addr, is_write, size, no_abort)                 \
    uptr read = is_write;                                                      \
    if (no_abort)                                                              \
        read |= 0xFFFFFFFF00000000;                                            \
                                                                               \
    __ockl_sanitizer_report(addr, caller_pc, WORKGROUP_ID(x), WORKGROUP_ID(y), \
                            WORKGROUP_ID(z), __ockl_get_local_linear_id(),     \
                            read, size);
