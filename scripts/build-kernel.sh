#!/bin/bash
set -euo pipefail

usage()
{
	cat <<'EOF'
Usage: build-kernel.sh --source DIR --work-dir NEW_DIR [--jobs N] [--verify-only]

Reproduce and build the validated Linux 6.18.38 patch/config inputs without
installing them or modifying DIR.  DIR must be the pristine Gentoo source
inventory identified in docs/provenance.md.  NEW_DIR must not already exist;
the script creates src, out, stage and logs beneath it.

Options:
  --source DIR    pristine Gentoo Linux 6.18.38 source tree
  --work-dir DIR  new, narrowly scoped build workspace
  --jobs N        parallel make jobs (default: online processor count)
  --verify-only   authenticate source/patch/config inputs, then stop
  -h, --help      show this help
EOF
}

die()
{
	printf 'build-kernel: %s\n' "$*" >&2
	exit 1
}

need()
{
	command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

hash_of()
{
	local value

	value=$(sha256sum "$1")
	printf '%s\n' "${value%% *}"
}

require_hash()
{
	local expected=$1
	local path=$2
	local actual

	actual=$(hash_of "$path")
	[[ $actual == "$expected" ]] ||
		die "hash mismatch for $path: expected $expected, found $actual"
}

source_tree=
work_arg=
verify_only=0
jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1\n')

while (( $# )); do
	case $1 in
	--source)
		(( $# >= 2 )) || die '--source requires a directory'
		source_tree=$2
		shift 2
		;;
	--work-dir)
		(( $# >= 2 )) || die '--work-dir requires a directory'
		work_arg=$2
		shift 2
		;;
	--jobs)
		(( $# >= 2 )) || die '--jobs requires a positive integer'
		jobs=$2
		shift 2
		;;
	--verify-only)
		verify_only=1
		shift
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		die "unknown argument: $1"
		;;
	esac
done

[[ -n $source_tree ]] || die '--source is required'
[[ -n $work_arg ]] || die '--work-dir is required'
[[ $jobs =~ ^[1-9][0-9]*$ ]] || die '--jobs must be a positive integer'

for command in awk cmp depmod file find git grep install make modinfo \
	objdump rsync sha256sum sort tee wc xargs; do
	need "$command"
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)
patch_dir=$repo_root/patches/linux
config_dir=$repo_root/config/kernel

[[ -f $source_tree/Makefile ]] || die "not a Linux source tree: $source_tree"
source_tree=$(cd -- "$source_tree" && pwd -P)

[[ ! -e $work_arg && ! -L $work_arg ]] ||
	die "work directory must not already exist: $work_arg"
work_parent=$(dirname -- "$work_arg")
work_name=$(basename -- "$work_arg")
[[ $work_name != . && $work_name != .. && -n $work_name ]] ||
	die 'invalid work-directory name'
[[ -d $work_parent ]] || die "work-directory parent does not exist: $work_parent"
work_parent=$(cd -- "$work_parent" && pwd -P)
work_dir=$work_parent/$work_name

case "$work_dir/" in
"$source_tree/"*|"$repo_root/"*)
	die 'work directory must be outside the source and repository trees'
	;;
esac

install -d -m 0755 -- "$work_dir/logs"
printf '%s\n' 'macbook2010-nouveau-build-v1' >"$work_dir/.build-layout"

expected_source_manifest=2509f40cfa992ae8aebeb9f8de355b80a6548f5828c6810ef2fbb5c06794401c
expected_source_symlinks=6633ea31dbf46be2fda9aa2d644ed4a36dfa1e42ac85bf060e9015547d747d47
expected_series=0cc92479944014e728d551700490ab8f6adf9643f5ff2cdef1974e270df0d001
expected_config_base=e87ab1f11254bc8b027c3410eace474f7c31fa564411be8a046df7d192c51674
expected_config_fragment=d9ae6a211ef010de0e815748c712392363e4e74fceb35b2714a010a0710da12d
expected_config=95b92db99f953e3845290700561ea8b067103134eaf1f5e08d23e044f952075f
expected_disassembly=85aadefccdb9fe54a4f5faaaed20cc6ff9c46665bdf55ec1de31aa8890d9228f
expected_release=6.18.38-gentoo-nouveau-prod2

expected_patch_names=(
	0001-instmem-iomapping.patch
	0002-nv50-pfifo-tlb-invalidate.patch
	0003-nva5-qword-bar2-read.patch
)
expected_patch_hashes=(
	d245e759d09021caed4df9cc45f0e8f17d841044beae0538d350bdfbf99df3c7
	43ed6403e63aabdb633e00bc4e54968ed593b8486e823799bdf93c1e5457114c
	7d9ab0db4078b2cad7703ca44b3d635dd96e848ed0184e354220533d6d829c63
)

printf 'Authenticating repository inputs...\n'
require_hash "$expected_series" "$patch_dir/series"
require_hash "$expected_config_base" "$config_dir/config-6.18.18-qword1.base"
require_hash "$expected_config_fragment" "$config_dir/macbookpro6-1-production.fragment"
require_hash "$expected_config" "$config_dir/config-6.18.38-prod2"

mapfile -t actual_series < <(grep -Ev '^[[:space:]]*(#|$)' "$patch_dir/series")
[[ ${#actual_series[@]} -eq ${#expected_patch_names[@]} ]] ||
	die 'accepted patch series has an unexpected number of entries'
for index in "${!expected_patch_names[@]}"; do
	[[ ${actual_series[index]} == "${expected_patch_names[index]}" ]] ||
		die "unexpected series entry $index: ${actual_series[index]}"
	require_hash "${expected_patch_hashes[index]}" \
		"$patch_dir/${expected_patch_names[index]}"
done
(
	cd -- "$repo_root"
	sha256sum -c patches/linux/SHA256SUMS
)

kernel_version=$(make -s -C "$source_tree" kernelversion)
[[ $kernel_version == 6.18.38-gentoo ]] ||
	die "expected Gentoo Linux 6.18.38-gentoo, found $kernel_version"

printf 'Authenticating pristine Gentoo source inventory...\n'
special=$(find "$source_tree" ! -type d ! -type f ! -type l -print -quit)
[[ -z $special ]] || die "unsupported special source-tree entry: $special"

(
	cd -- "$source_tree"
	find . -type f ! -path './patches.txt' -print0 |
		LC_ALL=C sort -z |
		xargs -0 sha256sum >"$work_dir/logs/source-tree.sha256"
	find . -type l -printf '%p -> %l\n' |
		LC_ALL=C sort >"$work_dir/logs/source-symlinks.txt"
)

source_file_count=$(wc -l <"$work_dir/logs/source-tree.sha256")
source_symlink_count=$(wc -l <"$work_dir/logs/source-symlinks.txt")
[[ $source_file_count -eq 91107 ]] ||
	die "unexpected source file count: $source_file_count"
[[ $source_symlink_count -eq 85 ]] ||
	die "unexpected source symlink count: $source_symlink_count"
require_hash "$expected_source_manifest" "$work_dir/logs/source-tree.sha256"
require_hash "$expected_source_symlinks" "$work_dir/logs/source-symlinks.txt"

printf 'Reconstructing and verifying the production config...\n'
config_verify=$work_dir/config-verify
install -d -m 0755 -- "$config_verify"
"$source_tree/scripts/kconfig/merge_config.sh" -m -O "$config_verify" \
	"$config_dir/config-6.18.18-qword1.base" \
	"$config_dir/macbookpro6-1-production.fragment" \
	>"$work_dir/logs/config-merge.log"
"$source_tree/scripts/config" --file "$config_verify/.config" \
	--set-str LOCALVERSION -nouveau-prod2
make -C "$source_tree" O="$config_verify" olddefconfig \
	>>"$work_dir/logs/config-merge.log"
cmp "$config_dir/config-6.18.38-prod2" "$config_verify/.config" ||
	die 'base + production fragment + olddefconfig did not reproduce the exact config'

if (( verify_only )); then
	printf '\nInput verification passed; --verify-only requested, so no build was started.\n'
	printf '  evidence: %s\n' "$work_dir/logs"
	exit 0
fi

src=$work_dir/src
out=$work_dir/out
stage=$work_dir/stage
install -d -m 0755 -- "$src" "$out" "$stage/boot"

printf 'Copying pristine source into the isolated workspace...\n'
rsync -a -- "$source_tree/" "$src/"

printf 'Applying the authenticated accepted series...\n'
for patch_name in "${expected_patch_names[@]}"; do
	patch_file=$patch_dir/$patch_name
	git -C "$src" apply --check "$patch_file" ||
		die "accepted patch does not apply to authenticated source: $patch_name"
	git -C "$src" apply "$patch_file"
	git -C "$src" apply --reverse --check "$patch_file" ||
		die "post-apply verification failed: $patch_name"
	printf '  applied: %s\n' "$patch_name"
done

install -m 0644 -- "$config_dir/config-6.18.38-prod2" "$out/.config"
make -C "$src" O="$out" olddefconfig
cmp "$config_dir/config-6.18.38-prod2" "$out/.config" ||
	die 'olddefconfig changed the production config in the patched tree'

release=$(make -s -C "$src" O="$out" kernelrelease)
[[ $release == "$expected_release" ]] || die "unexpected kernel release: $release"

printf 'Building %s with %s job(s)...\n' "$release" "$jobs"
make -C "$src" O="$out" -j"$jobs" 2>&1 | tee "$work_dir/logs/make.log"

cmp "$config_dir/config-6.18.38-prod2" "$out/.config" ||
	die 'production config changed during the build'
[[ $(make -s -C "$src" O="$out" kernelrelease) == "$expected_release" ]] ||
	die 'kernel release changed during the build'
file "$out/arch/x86/boot/bzImage" | grep -Fq "version $release " ||
	die 'bzImage does not embed the expected release'
[[ -s $out/System.map ]] || die 'System.map was not produced'
[[ -s $out/vmlinux ]] || die 'vmlinux was not produced'

object=$out/drivers/gpu/drm/nouveau/nvkm/subdev/instmem/nv50.o
disassembly=$work_dir/logs/qword-disassembly.txt
[[ -s $object ]] || die "missing built Nouveau object: $object"
objdump -dr --no-show-raw-insn "$object" |
	awk '/<nv50_instobj_memcpy_from>:/ { emit = 1 }
	     emit && /^$/ { emit = 0 }
	     emit { print }' >"$disassembly"

grep -Eq 'cmp[l]?[[:space:]]+\$0xa5' "$disassembly" ||
	die 'NVA5 chipset gate is absent from generated code'
grep -Fq 'memcpy_fromio' "$disassembly" ||
	die 'generic memcpy_fromio fallback is absent from generated code'
[[ $(grep -c 'lfence' "$disassembly") -eq 2 ]] ||
	die 'expected exactly two generated read barriers'
if grep -Eqi '%(xmm|ymm|zmm)|movnt' "$disassembly"; then
	die 'unexpected SIMD/non-temporal instruction in NVA5 read path'
fi
require_hash "$expected_disassembly" "$disassembly"

printf 'Staging and verifying modules without touching the live system...\n'
make -C "$src" O="$out" INSTALL_MOD_PATH="$stage" modules_install
depmod -b "$stage" -F "$out/System.map" "$release"

module_root=$stage/lib/modules/$release
[[ -d $module_root ]] || die 'staged module directory is absent'
module_count=0
while IFS= read -r -d '' module; do
	vermagic=$(modinfo -F vermagic "$module")
	case $vermagic in
	"$release "*) ;;
	*) die "bad module vermagic: $module: $vermagic" ;;
	esac
	((module_count += 1))
done < <(find "$module_root" -type f -name '*.ko*' -print0)
[[ $module_count -eq 157 ]] || die "expected 157 modules, found $module_count"
[[ -z $(find "$module_root" -type f -name '*.ko*' -size 0 -print -quit) ]] ||
	die 'a zero-length module was staged'

for index in modules.dep modules.alias modules.builtin modules.builtin.modinfo; do
	[[ -s $module_root/$index ]] || die "missing staged module index: $index"
done

install -m 0644 -- "$out/arch/x86/boot/bzImage" "$stage/boot/kernel-$release"
install -m 0644 -- "$out/System.map" "$stage/boot/System.map-$release"
install -m 0644 -- "$out/.config" "$stage/boot/config-$release"
(
	cd -- "$stage"
	find . -type f ! -name SHA256SUMS -print0 |
		LC_ALL=C sort -z |
		xargs -0 sha256sum >SHA256SUMS
	sha256sum -c SHA256SUMS
)

printf '\nBuild passed all repository gates.\n'
printf '  release:     %s\n' "$release"
printf '  source copy: %s\n' "$src"
printf '  build output:%s\n' " $out"
printf '  staged files:%s\n' " $stage"
printf '  evidence:    %s\n' "$work_dir/logs"
printf 'Nothing was installed.  Continue with docs/install-gentoo.md.\n'
