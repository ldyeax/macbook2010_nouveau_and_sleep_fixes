#!/bin/bash
set -euo pipefail

boot=${1:-0}
if [[ ! $boot =~ ^-?[0-9]+$ ]]; then
	printf 'usage: %s [journal-boot-offset]\n' "$0" >&2
	exit 2
fi

kernel_log=$(mktemp)
trap 'rm -f "$kernel_log"' EXIT
journalctl -b "$boot" -k --no-pager -o short-monotonic >"$kernel_log"

count()
{
	local pattern=$1
	grep -Ec "$pattern" "$kernel_log" || true
}

printf 'journal boot offset: %s\n' "$boot"
if [[ $boot == 0 ]]; then
	printf 'kernel:    %s\n' "$(uname -r)"
	printf 'cmdline:   '
	cat /proc/cmdline
	printf 'ignorelid: '
	cat /sys/module/nouveau/parameters/ignorelid 2>/dev/null || printf 'not-loaded\n'
	printf 'mem_sleep: '
	cat /sys/power/mem_sleep
	printf 'resume:    '
	cat /sys/power/resume
	printf 'PM timing: '
	cat /sys/power/pm_print_times

	printf '\nLive DRM connectors:\n'
	found_connector=0
	for status in /sys/class/drm/card*-*/status; do
		[[ -e $status ]] || continue
		found_connector=1
		printf '  %-24s %s\n' "${status%/status}" "$(<"$status")"
	done
	(( found_connector )) || printf '  none\n'

	printf '\nGPU driver:\n'
	lspci -nnk -s 01:00.0
else
	printf 'kernel log identity:\n'
	grep -m 1 -E 'Linux version |Kernel command line:' "$kernel_log" || true
fi

printf '\nNouveau fault counts for selected boot:\n'
printf '  DMA_PUSHER:      %s\n' "$(count 'nouveau.*DMA_PUSHER')"
printf '  CACHE_ERROR:     %s\n' "$(count 'nouveau.*CACHE_ERROR')"
printf '  INVALID_OPCODE:  %s\n' "$(count 'nouveau.*INVALID_OPCODE')"
printf '  TRAP_CCACHE:     %s\n' "$(count 'nouveau.*TRAP_CCACHE')"
printf '  trapped access:  %s\n' "$(count 'nouveau.*trapped (read|write)')"
printf '  MMU timeouts:    %s\n' "$(count 'nouveau.*mmu invalidate timeout')"
printf '  warnings/BUGs:   %s\n' "$(count '(WARNING:|BUG:|Call Trace:)')"

printf '\nFirst/last relevant kernel messages:\n'
faults=$(grep -E 'nouveau.*(DMA_PUSHER|CACHE_ERROR|TRAP|trapped|mmu invalidate)' \
	"$kernel_log" || true)
if [[ -n $faults ]]; then
	head -n 5 <<<"$faults"
	tail -n 5 <<<"$faults"
else
	printf '  none\n'
fi

printf '\nSuspend/resume timing messages:\n'
timings=$(grep -E 'PM: (suspend entry|suspend exit|suspend devices took|resume devices took)|Component: suspend devices' \
	"$kernel_log" || true)
if [[ -n $timings ]]; then
	tail -n 30 <<<"$timings"
else
	printf '  none\n'
fi
