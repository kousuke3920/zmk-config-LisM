# ====== 設定 ======
ZMK_APP_DIR := /workspaces/zmk/app
ZMK_CONFIG_DIR := /workspaces/zmk-config
ZMK_MODULE_DIR := /workspaces/zmk-modules

# このMakefileがあるディレクトリの絶対パス
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
OUTPUT_DIR := $(CURDIR)/firmware_builds
CONFIG_FILE := $(MAKEFILE_DIR)build.yaml

# ====== ツールチェック ======
YQ := $(shell command -v yq 2> /dev/null)
WEST := $(shell command -v west 2> /dev/null)

ifeq ($(YQ),)
  $(error "yq is not installed.")
endif
ifeq ($(WEST),)
  $(error "west is not installed.")
endif

.PHONY: all build clean debug

# ====== メインのビルドターゲット ======
all: build

build:
	@mkdir -p "$(OUTPUT_DIR)"
	@echo "Starting builds from $(CONFIG_FILE)..."
	@$(YQ) -c '.include[]' "$(CONFIG_FILE)" | while read -r build; do \
		artifact_name=$$(echo "$$build" | $(YQ) -r '."artifact-name" // "zmk"'); \
		board=$$(echo "$$build" | $(YQ) -r '.board'); \
		shield=$$(echo "$$build" | $(YQ) -r '.shield // ""'); \
		overlay_path=$$(echo "$$build" | $(YQ) -r '."overlay-path" // ""'); \
		cmake_args=$$(echo "$$build" | $(YQ) -r '."cmake-args" // ""'); \
		snippet=$$(echo "$$build" | $(YQ) -r '.snippet // ""'); \
		\
		overlay_abs=""; \
		if [ -n "$$overlay_path" ]; then \
			overlay_abs="-DDTC_OVERLAY_FILE=$(ZMK_MODULE_DIR)/$$overlay_path;$(MAKEFILE_DIR)config/lism.keymap"; \
		fi; \
		\
		echo "🚧 Building $$artifact_name (board=$$board, shield=$$shield, artifact_name=$$artifact_name)"; \
		echo "$(MAKEFILE_DIR)config"; \
		cd $(ZMK_APP_DIR) && \
		$(WEST) build -p auto -b $$board -d build/$$artifact_name \
			${snippet:+-S "$$snippet"} \
			-- \
			-DZMK_CONFIG="$(MAKEFILE_DIR)config" \
			-DSHIELD="$$shield" \
			$$overlay_abs \
			-DZMK_EXTRA_MODULES="$(ZMK_MODULE_DIR)/zmk-keyboards-LisM;$(ZMK_MODULE_DIR)/zmk-driver-paw3222/;$(ZMK_MODULE_DIR)/zmk-rgbled-widget" \
			$$cmake_args; \
		\
		if [ -f $(ZMK_APP_DIR)/build/$$artifact_name/zephyr/zmk.uf2 ]; then \
			cp $(ZMK_APP_DIR)/build/$$artifact_name/zephyr/zmk.uf2 $(OUTPUT_DIR)/$$artifact_name.uf2; \
			echo "✅ Built: $(OUTPUT_DIR)/$$artifact_name.uf2"; \
		else \
			echo "❌ Build failed: zmk.uf2 not found for $$artifact_name"; \
		fi; \
	done
	@echo "🎉 All builds completed!"

# ====== クリーン ======
clean:
	@echo "🧹 Cleaning..."
	@rm -rf "$(ZMK_APP_DIR)/build"
	@rm -rf "$(OUTPUT_DIR)"
	@echo "🧹 Cleaned!"