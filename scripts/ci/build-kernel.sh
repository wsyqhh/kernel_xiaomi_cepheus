#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:?source dir is required}"
CI_DIR="${2:?ci dir is required}"
VARIANT="${3:-verify}"
CONFIG_FRAGMENT="${4:-}"

ROOT_DIR="$(cd "$SOURCE_DIR" && pwd)"
CI_DIR="$(cd "$CI_DIR" && pwd)"
OUT_DIR="$ROOT_DIR/out"
ARTIFACT_DIR="$ROOT_DIR/artifacts/$VARIANT"

mkdir -p "$OUT_DIR" "$ARTIFACT_DIR"
cd "$ROOT_DIR"

KSU_COMMIT="4600bfc66490921ebe813d887bc63f04629baa6f"
if [[ ! -f KernelSU-Next/kernel/Kconfig ]]; then
  rm -rf KernelSU-Next
  git clone https://github.com/KernelSU-Next/KernelSU-Next.git KernelSU-Next
  git -C KernelSU-Next checkout "$KSU_COMMIT"
fi

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
  scripts/kconfig/merge_config.sh -m -O "$OUT_DIR" "$OUT_DIR/.config" "$CI_DIR/$CONFIG_FRAGMENT"
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
