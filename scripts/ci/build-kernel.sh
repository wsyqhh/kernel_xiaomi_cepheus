#!/usr/bin/env bash
set -euo pipefail

VARIANT="${1:-verify}"
CONFIG_FRAGMENT="${2:-}"

ROOT_DIR="$(pwd)"
OUT_DIR="$ROOT_DIR/out"
ARTIFACT_DIR="$ROOT_DIR/artifacts/$VARIANT"

mkdir -p "$OUT_DIR" "$ARTIFACT_DIR"

export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=github
export KBUILD_BUILD_HOST=actions
export PATH="${CLANG_BIN:?CLANG_BIN is not set}:$PATH"
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

MAKE_ARGS=(
  O="$OUT_DIR"
  LLVM=1
  LLVM_IAS=1
)

make "${MAKE_ARGS[@]}" cepheus_defconfig

if [[ -n "$CONFIG_FRAGMENT" ]]; then
  scripts/kconfig/merge_config.sh -m -O "$OUT_DIR" "$OUT_DIR/.config" "$CONFIG_FRAGMENT"
  yes "" | make "${MAKE_ARGS[@]}" olddefconfig
fi

make "${MAKE_ARGS[@]}" -j"$(nproc)"

make "${MAKE_ARGS[@]}" kernelrelease > "$ARTIFACT_DIR/KERNELRELEASE"
cp "$OUT_DIR/.config" "$ARTIFACT_DIR/config-$VARIANT"
cp "$OUT_DIR/arch/arm64/boot/Image.gz-dtb" "$ARTIFACT_DIR/Image.gz-dtb"

(
  cd "$ARTIFACT_DIR"
  sha256sum Image.gz-dtb "config-$VARIANT" KERNELRELEASE > SHA256SUMS
  zip -9 "cepheus-$VARIANT-kernel.zip" Image.gz-dtb "config-$VARIANT" KERNELRELEASE SHA256SUMS
)
