PROJECT_NAME := BilineIME
SETTINGS_SCHEME := BilineSettingsDev
BROKER_SCHEME := BilineBrokerDev
DERIVED_DATA := $(HOME)/Library/Caches/BilineIME/DerivedData
CONFIGURATION ?= Debug
INSTALL_SCOPE ?= user
REMOVE_SCOPE ?= user
REMOVE_DATA ?= preserve
RESET_SCOPE ?= all
RESET_DEPTH ?= cache-prune
SMOKE_SCENARIO ?= full
BILINECTL := swift run bilinectl

ifeq ($(BILINE_AD_HOC_SIGN),1)
SETTINGS_SIGN_FLAGS := CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES DEVELOPMENT_TEAM=
else
SETTINGS_SIGN_FLAGS :=
endif

.PHONY: bootstrap project test build-ime build-settings build-broker install-ime remove-ime reset-ime prepare-release-env diagnose-ime configure-aliyun-credentials aliyun-credentials-status verify-ime smoke-ime-host smoke-ime-host-check smoke-ime-host-prepare format verify dev-pkg

bootstrap:
	brew install xcodegen swift-format cmake boost

project:
	xcodegen generate

test:
	./scripts/build-librime.sh
	swift test

build-ime: project
	./scripts/build-ime-dev.sh

build-settings: project
	xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SETTINGS_SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) $(SETTINGS_SIGN_FLAGS) build

build-broker: project
	xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(BROKER_SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) $(SETTINGS_SIGN_FLAGS) build

install-ime:
	$(BILINECTL) install dev --scope $(INSTALL_SCOPE) --confirm

remove-ime:
	$(BILINECTL) remove dev --scope $(REMOVE_SCOPE) --data $(REMOVE_DATA) --confirm

reset-ime:
	@if [ "$(CONFIRM)" = "1" ]; then \
		$(BILINECTL) reset dev --scope $(RESET_SCOPE) --depth $(RESET_DEPTH) --confirm; \
	else \
		$(BILINECTL) plan reset dev --scope $(RESET_SCOPE) --depth $(RESET_DEPTH); \
		echo "Dry run only. Re-run with CONFIRM=1 to execute."; \
	fi

prepare-release-env:
	@if [ "$(CONFIRM)" = "1" ]; then \
		$(BILINECTL) prepare-release dev --scope all --confirm; \
	else \
		$(BILINECTL) plan prepare-release dev --scope all; \
		echo "Dry run only. Re-run with CONFIRM=1 to execute."; \
	fi

diagnose-ime:
	$(BILINECTL) diagnose dev

configure-aliyun-credentials:
	$(BILINECTL) credentials configure dev

aliyun-credentials-status:
	$(BILINECTL) credentials status dev

verify-ime:
	./scripts/build-librime.sh
	swift test --filter 'InputControllerEventRouterTests|BilingualInputSessionTests|BilineRimeTests'
	$(MAKE) build-ime
	$(MAKE) install-ime
	@echo "Manual host verification required: stop here and ask the user to select BilineIME Dev, focus TextEdit, and type the requested cases."

smoke-ime-host-check:
	$(BILINECTL) smoke-host dev --check

smoke-ime-host-prepare:
	$(BILINECTL) smoke-host dev --prepare

smoke-ime-host:
	$(BILINECTL) smoke-host dev --scenario $(SMOKE_SCENARIO) --confirm

format:
	swift-format format -i $$(find App Sources Tests -name '*.swift' -print)

verify: test build-ime build-settings

dev-pkg:
	BILINE_AD_HOC_SIGN=1 ./scripts/build-dev-pkg.sh
