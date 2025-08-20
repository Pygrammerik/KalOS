#!/usr/bin/env bash
set -euo pipefail

# Конфигурация через переменные окружения (с дефолтами)
KERNEL_VERSION="${KERNEL_VERSION:-6.6.35}"
BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"

ROOT_DIR="$(pwd)"
OUT_DIR="$ROOT_DIR/out"
WORK_DIR="$ROOT_DIR/work"
DL_DIR="$ROOT_DIR/downloads"
INIT_SRC="$ROOT_DIR/initramfs/init"

mkdir -p "$OUT_DIR" "$WORK_DIR" "$DL_DIR"

echo "==> Versions: kernel=$KERNEL_VERSION, busybox=$BUSYBOX_VERSION"

# -----------------------------
# Загрузка исходников
# -----------------------------
KERNEL_TARBALL="linux-$KERNEL_VERSION.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TARBALL}"

BUSYBOX_TARBALL="busybox-$BUSYBOX_VERSION.tar.bz2"
BUSYBOX_URL="https://busybox.net/downloads/${BUSYBOX_TARBALL}"

if [[ ! -f "$DL_DIR/$KERNEL_TARBALL" ]]; then
    echo "==> Download kernel $KERNEL_VERSION"
    curl -fL "$KERNEL_URL" -o "$DL_DIR/$KERNEL_TARBALL"
fi

if [[ ! -f "$DL_DIR/$BUSYBOX_TARBALL" ]]; then
    echo "==> Download busybox $BUSYBOX_VERSION"
    curl -fL "$BUSYBOX_URL" -o "$DL_DIR/$BUSYBOX_TARBALL"
fi

# -----------------------------
# Сборка BusyBox (статически)
# -----------------------------
BUSYBOX_BUILD="$WORK_DIR/busybox-$BUSYBOX_VERSION"
if [[ ! -d "$BUSYBOX_BUILD" ]]; then
    echo "==> Extract busybox"
    tar -C "$WORK_DIR" -xf "$DL_DIR/$BUSYBOX_TARBALL"
fi

pushd "$BUSYBOX_BUILD" >/dev/null
echo "==> Configure busybox (static)"
make defconfig >/dev/null
# Жёстко задаём единичные значения без дублей в .config
tmpcfg=".config.tmp"
grep -v -E '^(# CONFIG_STATIC is not set|CONFIG_STATIC=)' .config > "$tmpcfg" || true
printf 'CONFIG_STATIC=y\n' >> "$tmpcfg"
mv "$tmpcfg" .config

# Предпочитаем симлинки для апплетов, если опция присутствует в дефконфиге
if grep -q -E '^(# CONFIG_INSTALL_APPLET_SYMLINKS is not set|CONFIG_INSTALL_APPLET_SYMLINKS=)' .config; then
    grep -v -E '^(# CONFIG_INSTALL_APPLET_SYMLINKS is not set|CONFIG_INSTALL_APPLET_SYMLINKS=)' .config > "$tmpcfg" || true
    printf 'CONFIG_INSTALL_APPLET_SYMLINKS=y\n' >> "$tmpcfg"
    mv "$tmpcfg" .config
fi

yes "" | make oldconfig >/dev/null
make -j"$(nproc)" >/dev/null

ROOTFS_DIR="$WORK_DIR/rootfs"
rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"
make CONFIG_PREFIX="$ROOTFS_DIR" install >/dev/null
popd >/dev/null

# Минимальные каталоги и устройства
mkdir -p "$ROOTFS_DIR"/proc "$ROOTFS_DIR"/sys "$ROOTFS_DIR"/dev "$ROOTFS_DIR"/etc "$ROOTFS_DIR"/tmp "$ROOTFS_DIR"/mnt "$ROOTFS_DIR"/root "$ROOTFS_DIR"/usr/bin "$ROOTFS_DIR"/usr/sbin
chmod 1777 "$ROOTFS_DIR"/tmp

if [[ ! -e "$ROOTFS_DIR/dev/console" ]]; then
    mknod -m 600 "$ROOTFS_DIR/dev/console" c 5 1
fi
if [[ ! -e "$ROOTFS_DIR/dev/null" ]]; then
    mknod -m 666 "$ROOTFS_DIR/dev/null" c 1 3
fi

# Копируем init
install -m 0755 "$INIT_SRC" "$ROOTFS_DIR/init"

# Сборка initramfs
echo "==> Build initramfs"
pushd "$ROOTFS_DIR" >/dev/null
find . | cpio -H newc -o 2>/dev/null | gzip -9 > "$OUT_DIR/initramfs.cpio.gz"
popd >/dev/null

# -----------------------------
# Сборка ядра Linux
# -----------------------------
KERNEL_BUILD="$WORK_DIR/linux-$KERNEL_VERSION"
if [[ ! -d "$KERNEL_BUILD" ]]; then
    echo "==> Extract kernel"
    tar -C "$WORK_DIR" -xf "$DL_DIR/$KERNEL_TARBALL"
fi

pushd "$KERNEL_BUILD" >/dev/null
echo "==> Configure kernel"
make mrproper >/dev/null
make defconfig >/dev/null

# Включаем поддержку initramfs и devtmpfs
scripts/config --file .config \
  -e BLK_DEV_INITRD \
  -e DEVTMPFS \
  -e DEVTMPFS_MOUNT \
  -e TMPFS \
  -e PROC_FS \
  -e SYSFS

make olddefconfig >/dev/null
echo "==> Build kernel (bzImage)"
make -j"$(nproc)" bzImage >/dev/null
popd >/dev/null

install -D -m 0644 "$KERNEL_BUILD/arch/x86/boot/bzImage" "$OUT_DIR/vmlinuz"

# -----------------------------
# Формирование ISO (GRUB)
# -----------------------------
ISO_STAGING="$WORK_DIR/iso"
rm -rf "$ISO_STAGING"
mkdir -p "$ISO_STAGING/boot/grub"
install -m 0644 "$OUT_DIR/vmlinuz" "$ISO_STAGING/boot/vmlinuz"
install -m 0644 "$OUT_DIR/initramfs.cpio.gz" "$ISO_STAGING/boot/initramfs.cpio.gz"

cat > "$ISO_STAGING/boot/grub/grub.cfg" << 'EOF'
set timeout=0
set default=0

menuentry "KalOS (console only)" {
    linux /boot/vmlinuz console=ttyS0 console=tty0 quiet
    initrd /boot/initramfs.cpio.gz
}
EOF

echo "==> Create ISO"
grub-mkrescue -o "$OUT_DIR/kalos.iso" "$ISO_STAGING" >/dev/null

echo "==> Done: $OUT_DIR/kalos.iso"


