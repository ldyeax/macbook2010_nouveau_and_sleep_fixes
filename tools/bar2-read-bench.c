#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <immintrin.h>
#include <inttypes.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define BAR2_WC "/sys/bus/pci/devices/0000:01:00.0/resource3_wc"
#define COPY_SIZE (1024UL * 1024UL)

typedef void (*copy_fn)(void *, const volatile void *, size_t);

static void fault(int sig)
{
	dprintf(STDERR_FILENO, "BAR2 read caught signal %d\n", sig);
	_exit(128 + sig);
}

static void copy_rep32(void *dst, const volatile void *src, size_t len)
{
	void *d = dst;
	const volatile void *s = src;
	size_t count = len / 4;

	asm volatile("rep movsl"
		     : "+D" (d), "+S" (s), "+c" (count)
		     :
		     : "memory");
}

static void copy_rep8(void *dst, const volatile void *src, size_t len)
{
	void *d = dst;
	const volatile void *s = src;
	size_t count = len;

	asm volatile("rep movsb"
		     : "+D" (d), "+S" (s), "+c" (count)
		     :
		     : "memory");
}

static void copy_rep64(void *dst, const volatile void *src, size_t len)
{
	void *d = dst;
	const volatile void *s = src;
	size_t count = len / 8;

	asm volatile("rep movsq"
		     : "+D" (d), "+S" (s), "+c" (count)
		     :
		     : "memory");
}

static void copy_gpr64(void *dst, const volatile void *src, size_t len)
{
	char *d = dst;
	const volatile char *s = src;

	for (size_t i = 0; i < len; i += 64) {
		asm volatile("movq  0(%0), %%rax\n\t"
			     "movq  8(%0), %%rcx\n\t"
			     "movq 16(%0), %%rdx\n\t"
			     "movq 24(%0), %%r8\n\t"
			     "movq 32(%0), %%r9\n\t"
			     "movq 40(%0), %%r10\n\t"
			     "movq 48(%0), %%r11\n\t"
			     "movq 56(%0), %%r12\n\t"
			     "movq %%rax,  0(%1)\n\t"
			     "movq %%rcx,  8(%1)\n\t"
			     "movq %%rdx, 16(%1)\n\t"
			     "movq %%r8,  24(%1)\n\t"
			     "movq %%r9,  32(%1)\n\t"
			     "movq %%r10, 40(%1)\n\t"
			     "movq %%r11, 48(%1)\n\t"
			     "movq %%r12, 56(%1)"
			     :
			     : "r" (s + i), "r" (d + i)
			     : "rax", "rcx", "rdx", "r8", "r9", "r10",
			       "r11", "r12", "memory");
	}
}

/* Match the 32-byte forward loop in arch/x86/lib/memcpy_64.S. */
static void copy_gpr64x4(void *dst, const volatile void *src, size_t len)
{
	char *d = dst;
	const volatile char *s = src;

	for (size_t i = 0; i < len; i += 32) {
		asm volatile("movq  0(%0), %%r8\n\t"
			     "movq  8(%0), %%r9\n\t"
			     "movq 16(%0), %%r10\n\t"
			     "movq 24(%0), %%r11\n\t"
			     "movq %%r8,   0(%1)\n\t"
			     "movq %%r9,   8(%1)\n\t"
			     "movq %%r10, 16(%1)\n\t"
			     "movq %%r11, 24(%1)"
			     :
			     : "r" (s + i), "r" (d + i)
			     : "r8", "r9", "r10", "r11", "memory");
	}
}

static void copy_scalar32(void *dst, const volatile void *src, size_t len)
{
	uint32_t *d = dst;
	const volatile uint32_t *s = src;
	size_t count = len / sizeof(*s);

	for (size_t i = 0; i < count; i++)
		d[i] = s[i];
}

static void copy_scalar64(void *dst, const volatile void *src, size_t len)
{
	uint64_t *d = dst;
	const volatile uint64_t *s = src;
	size_t count = len / sizeof(*s);

	for (size_t i = 0; i < count; i += 8) {
		uint64_t a = s[i + 0];
		uint64_t b = s[i + 1];
		uint64_t c = s[i + 2];
		uint64_t e = s[i + 3];
		uint64_t f = s[i + 4];
		uint64_t g = s[i + 5];
		uint64_t h = s[i + 6];
		uint64_t j = s[i + 7];

		d[i + 0] = a;
		d[i + 1] = b;
		d[i + 2] = c;
		d[i + 3] = e;
		d[i + 4] = f;
		d[i + 5] = g;
		d[i + 6] = h;
		d[i + 7] = j;
	}
}

static void copy_movdqa(void *dst, const volatile void *src, size_t len)
{
	char *d = dst;
	const volatile char *s = src;

	for (size_t i = 0; i < len; i += 64) {
		asm volatile("movdqa   0(%0), %%xmm0\n\t"
			     "movdqa  16(%0), %%xmm1\n\t"
			     "movdqa  32(%0), %%xmm2\n\t"
			     "movdqa  48(%0), %%xmm3\n\t"
			     "movdqa %%xmm0,   0(%1)\n\t"
			     "movdqa %%xmm1,  16(%1)\n\t"
			     "movdqa %%xmm2,  32(%1)\n\t"
			     "movdqa %%xmm3,  48(%1)"
			     :
			     : "r" (s + i), "r" (d + i)
			     : "xmm0", "xmm1", "xmm2", "xmm3", "memory");
	}
}

static void copy_movntdqa(void *dst, const volatile void *src, size_t len)
{
	char *d = dst;
	const volatile char *s = src;

	for (size_t i = 0; i < len; i += 64) {
		asm volatile("movntdqa   0(%0), %%xmm0\n\t"
			     "movntdqa  16(%0), %%xmm1\n\t"
			     "movntdqa  32(%0), %%xmm2\n\t"
			     "movntdqa  48(%0), %%xmm3\n\t"
			     "movdqa %%xmm0,   0(%1)\n\t"
			     "movdqa %%xmm1,  16(%1)\n\t"
			     "movdqa %%xmm2,  32(%1)\n\t"
			     "movdqa %%xmm3,  48(%1)"
			     :
			     : "r" (s + i), "r" (d + i)
			     : "xmm0", "xmm1", "xmm2", "xmm3", "memory");
	}
}

static void copy_libc(void *dst, const volatile void *src, size_t len)
{
	memcpy(dst, (const void *)src, len);
}

static uint64_t checksum(const uint8_t *p, size_t len)
{
	uint64_t value = 1469598103934665603ULL;

	for (size_t i = 0; i < len; i++) {
		value ^= p[i];
		value *= 1099511628211ULL;
	}
	return value;
}

static void run_one(const char *name, copy_fn fn, void *dst,
		    const volatile void *src, size_t len)
{
	struct timespec begin, end;
	double seconds;

	memset(dst, 0, len);
	clock_gettime(CLOCK_MONOTONIC_RAW, &begin);
	fn(dst, src, len);
	_mm_mfence();
	clock_gettime(CLOCK_MONOTONIC_RAW, &end);
	seconds = end.tv_sec - begin.tv_sec +
		  (end.tv_nsec - begin.tv_nsec) / 1000000000.0;
	printf("%-12s %9.6f s  %8.3f MiB/s  checksum=%016" PRIx64 "\n",
	       name, seconds, len / (1024.0 * 1024.0) / seconds,
	       checksum(dst, len));
}

int main(void)
{
	static const struct {
		const char *name;
		copy_fn fn;
	} tests[] = {
		{ "rep-movsl", copy_rep32 },
		{ "rep-movsb", copy_rep8 },
		{ "rep-movsq", copy_rep64 },
		{ "gpr-u64x8", copy_gpr64 },
		{ "gpr-u64x4", copy_gpr64x4 },
		{ "scalar-u32", copy_scalar32 },
		{ "scalar-u64", copy_scalar64 },
		{ "movdqa", copy_movdqa },
		{ "movntdqa", copy_movntdqa },
		{ "libc-memcpy", copy_libc },
	};
	void *dst = NULL;
	void *map;
	int fd;

	signal(SIGBUS, fault);
	signal(SIGSEGV, fault);
	fd = open(BAR2_WC, O_RDONLY | O_CLOEXEC | O_SYNC);
	if (fd < 0) {
		perror("open " BAR2_WC);
		return 1;
	}
	map = mmap(NULL, COPY_SIZE, PROT_READ, MAP_SHARED, fd, 0);
	if (map == MAP_FAILED) {
		perror("mmap " BAR2_WC);
		return 1;
	}
	if (posix_memalign(&dst, 64, COPY_SIZE)) {
		fprintf(stderr, "posix_memalign failed\n");
		return 1;
	}

	printf("Read-only WC BAR2 benchmark: %lu bytes at offset 0\n", COPY_SIZE);
	for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++)
		run_one(tests[i].name, tests[i].fn, dst, map, COPY_SIZE);

	free(dst);
	munmap(map, COPY_SIZE);
	close(fd);
	return 0;
}
