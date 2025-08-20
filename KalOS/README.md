## KalOS (минимальный Linux, только консоль)

Этот проект собирает сверхминимальный Live-ISO образ Linux с ядром и BusyBox без пакетного менеджера — только командная строка. Подходит для ознакомления и быстрого запуска в виртуалке.

### Что внутри
- Ядро Linux (x86_64, defconfig)
- BusyBox (статически собранный)
- initramfs с простым init-скриптом, который загружает консоль `/bin/sh`
- Загрузчик GRUB для ISO

### Требования
- Windows 10/11 с Docker Desktop (WSL2 backend) или любая ОС с Docker
- Интернет для загрузки исходников ядра и BusyBox

### Быстрый старт (Windows + Docker Desktop)
1) Откройте PowerShell в корне репозитория (папка `KalOS`).
2) Соберите ISO:
   ```bash
   make iso
   ```
   Готовый образ появится в `KalOS/out/kalos.iso`.

### Запуск в QEMU (опционально)
Если QEMU установлен (например, в WSL/Ubuntu):
```bash
make run-qemu
```
Либо напрямую:
```bash
qemu-system-x86_64 -m 512 -cdrom out/kalos.iso -boot d -serial mon:stdio
```

После загрузки вы попадёте в BusyBox shell (`/bin/sh`). Для перезагрузки используйте `reboot -f`.

### Структура
- `Dockerfile` — контейнер со всеми зависимостями для сборки
- `Makefile` — удобные цели: `iso`, `clean`, `run-qemu`
- `build/build.sh` — автоматизация сборки ядра, BusyBox и ISO
- `initramfs/init` — init-скрипт для раннего userspace

### Настройка версий
Версии ядра и BusyBox задаются через аргументы сборки Docker:
```bash
docker build --build-arg KERNEL_VERSION=6.6.35 --build-arg BUSYBOX_VERSION=1.36.1 -t kalos-builder -f Dockerfile .
```
По умолчанию используются LTS-ветки (см. `Dockerfile`).

### Примечания
- ISO не содержит пакетного менеджера и дополнительных пакетов — только консоль BusyBox.
- Сборка ядра может занять существенное время при первом запуске.


