#include "shadow_mapping.h"
#include "tsan_util.h"

USED NO_INLINE NO_SANITIZE_THREAD void
__tsan_func_entry(void *pc)
{
}

USED NO_INLINE NO_SANITIZE_THREAD void
__tsan_func_exit()
{
}

USED NO_INLINE NO_SANITIZE_THREAD void
__tsan_read4(void *addr)
{
}

USED NO_INLINE NO_SANITIZE_THREAD void
__tsan_read1(void *addr)
{
}

USED NO_INLINE NO_SANITIZE_THREAD void
__tsan_write4(void *addr)
{
}

typedef enum {
    mo_relaxed,
    mo_consume,
    mo_acquire,
    mo_release,
    mo_acq_rel,
    mo_seq_cst
} morder;

USED NO_INLINE NO_SANITIZE_THREAD int
__tsan_atomic32_load(const volatile int *a, morder mo)
{
    return 1;
}

USED NO_INLINE NO_SANITIZE_THREAD long long int
__tsan_atomic64_load(const volatile long long int *a, morder mo)
{
    return 0LL;
}

USED NO_INLINE NO_SANITIZE_THREAD void
__tsan_atomic64_store(volatile long long int *a, long long int v, morder mo)
{
}

USED NO_INLINE NO_SANITIZE_THREAD void
__tsan_atomic32_fetch_add(void *addr, int value, morder mo)
{
}

USED NO_INLINE NO_SANITIZE_THREAD void
__tsan_atomic64_fetch_add(void *addr, long long int value, morder mo)
{
}

USED NO_INLINE NO_SANITIZE_THREAD long long int
__tsan_atomic64_compare_exchange_val(volatile long long int *a, long long int c,
                                     long long int v, morder mo, morder fmo)
{
    return 0LL;
}

USED NO_INLINE NO_SANITIZE_THREAD void *
__tsan_memcpy(void *dest, const void *src, unsigned long long count)
{
    return 0ULL;
}
