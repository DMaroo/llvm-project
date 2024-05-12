/*===--------------------------------------------------------------------------
 *                   ROCm Device Libraries
 *
 * This file is distributed under the University of Illinois Open Source
 * License. See LICENSE.TXT for details.
 *===------------------------------------------------------------------------*/

#pragma once
#include "tsan_util.h"
#include "ockl.h"

// offsets from llvm/compiler-rt/lib/tsan/rtl/tsan_platform.h

/*
C/C++ on linux/x86_64 and freebsd/x86_64
0000 0000 1000 - 0200 0000 0000: main binary and/or MAP_32BIT mappings (2TB)
0200 0000 0000 - 1000 0000 0000: -
1000 0000 0000 - 3000 0000 0000: shadow (32TB)
3000 0000 0000 - 3800 0000 0000: metainfo (memory blocks and sync objects; 8TB)
3800 0000 0000 - 5500 0000 0000: -
5500 0000 0000 - 5a00 0000 0000: pie binaries without ASLR or on 4.1+ kernels
5a00 0000 0000 - 7200 0000 0000: -
7200 0000 0000 - 7300 0000 0000: heap (1TB)
7300 0000 0000 - 7a00 0000 0000: -
7a00 0000 0000 - 8000 0000 0000: modules and main thread stack (6TB)

C/C++ on netbsd/amd64 can reuse the same mapping:
 * The address space starts from 0x1000 (option with 0x0) and ends with
   0x7f7ffffff000.
 * LoAppMem-kHeapMemEnd can be reused as it is.
 * No VDSO support.
 * No MidAppMem region.
 * No additional HeapMem region.
 * HiAppMem contains the stack, loader, shared libraries and heap.
 * Stack on NetBSD/amd64 has prereserved 128MB.
 * Heap grows downwards (top-down).
 * ASLR must be disabled per-process or globally.
*/
static const unsigned long long kMetaShadowBeg = 0x300000000000ull;
static const unsigned long long kMetaShadowEnd = 0x380000000000ull;
static const unsigned long long kShadowBeg = 0x100000000000ull;
static const unsigned long long kShadowEnd = 0x300000000000ull;
static const unsigned long long kHeapMemBeg = 0x720000000000ull;
static const unsigned long long kHeapMemEnd = 0x730000000000ull;
static const unsigned long long kLoAppMemBeg = 0x000000001000ull;
static const unsigned long long kLoAppMemEnd = 0x020000000000ull;
static const unsigned long long kMidAppMemBeg = 0x550000000000ull;
static const unsigned long long kMidAppMemEnd = 0x5a0000000000ull;
static const unsigned long long kHiAppMemBeg = 0x7a0000000000ull;
static const unsigned long long kHiAppMemEnd = 0x800000000000ull;
static const unsigned long long kShadowMsk = 0x700000000000ull;
static const unsigned long long kShadowXor = 0x000000000000ull;
static const unsigned long long kShadowAdd = 0x100000000000ull;
static const unsigned long long kVdsoBeg = 0xf000000000000000ull;

#define MEM_TO_SHADOW(mem_addr)                                                \
    (((((mem_addr) >> TSAN_SHADOW) << SHADOW_WORDS_LEVEL) &                    \
      (kShadowEnd - kShadowBeg - 1)) +                                         \
     kShadowBeg);
