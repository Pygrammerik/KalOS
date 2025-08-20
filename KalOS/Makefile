IMAGE_NAME ?= kalos-builder
DOCKER ?= docker
KERNEL_VERSION ?= 6.6.35
BUSYBOX_VERSION ?= 1.36.1

TARGET_ISO := out/kalos.iso

.PHONY: iso build-image clean run-qemu

build-image:
	$(DOCKER) build \
		--build-arg KERNEL_VERSION=$(KERNEL_VERSION) \
		--build-arg BUSYBOX_VERSION=$(BUSYBOX_VERSION) \
		-t $(IMAGE_NAME) -f Dockerfile .

iso: build-image
	$(DOCKER) run --rm -v ${PWD}:/src -w /src \
		-e KERNEL_VERSION=$(KERNEL_VERSION) \
		-e BUSYBOX_VERSION=$(BUSYBOX_VERSION) \
		$(IMAGE_NAME) bash -lc "bash /src/build/build.sh"

run-qemu: $(TARGET_ISO)
	qemu-system-x86_64 -m 512 -cdrom $(TARGET_ISO) -boot d -serial mon:stdio

$(TARGET_ISO):
	@echo "ISO не найден. Соберите его: make iso"
	@exit 1

clean:
	rm -rf out work downloads


