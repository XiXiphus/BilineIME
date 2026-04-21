PROJECT_NAME := BilineIME
SETTINGS_SCHEME := BilineSettingsDev
DERIVED_DATA := $(HOME)/Library/Caches/BilineIME/DerivedData
CONFIGURATION ?= Debug
REPAIR_LEVEL ?= 2
BILINECTL := swift run bilinectl

.PHONY: bootstrap project test build-ime build-settings install-ime uninstall-ime repair-ime diagnose-ime configure-aliyun-credentials aliyun-credentials-status verify-ime format verify

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
	xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SETTINGS_SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

install-ime:
	$(BILINECTL) reinstall dev --level 1 --confirm

uninstall-ime:
	$(BILINECTL) uninstall dev --confirm

repair-ime:
	@if [ "$(CONFIRM)" = "1" ]; then \
		$(BILINECTL) reinstall dev --level $(REPAIR_LEVEL) --confirm; \
	else \
		$(BILINECTL) plan reinstall dev --level $(REPAIR_LEVEL); \
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

format:
	swift-format format -i $$(find App Sources Tests -name '*.swift' -print)

verify: test build-ime build-settings
