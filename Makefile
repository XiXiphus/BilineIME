PROJECT_NAME := BilineIME
DEV_SCHEME := BilineIMEDev
RELEASE_SCHEME := BilineIME
SETTINGS_SCHEME := BilineSettingsDev
DERIVED_DATA := $(HOME)/Library/Caches/BilineIME/DerivedData
CONFIGURATION ?= Debug
REPAIR_LEVEL ?= 2
BILINECTL := swift run bilinectl

.PHONY: bootstrap project test build-ime build-ime-release build-settings install-settings-dev install-ime uninstall-ime reset-ime reset-dev-apps repair-ime package-release package-internal diagnose-ime diagnose-ime-dev diagnose-ime-release diagnose-dev-apps configure-aliyun-credentials aliyun-credentials-status smoke-ime smoke-ime-aliyun smoke-ime-release verify-ime format verify

bootstrap:
	brew install xcodegen swift-format cmake boost

project:
	xcodegen generate

test:
	./scripts/build-librime.sh
	swift test

build-ime: project
	./scripts/build-ime-dev.sh

build-ime-release: project
	./scripts/build-ime-release.sh

build-settings: project
	xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SETTINGS_SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

install-settings-dev:
	$(BILINECTL) reinstall dev --level 1 --confirm

install-ime:
	$(BILINECTL) reinstall dev --level 1 --confirm

uninstall-ime:
	./scripts/uninstall-ime.sh

reset-ime:
	$(BILINECTL) reinstall dev --level 1 --confirm

reset-dev-apps:
	$(BILINECTL) reinstall dev --level 1 --confirm

repair-ime:
	@if [ "$(CONFIRM)" = "1" ]; then \
		$(BILINECTL) reinstall dev --level $(REPAIR_LEVEL) --confirm; \
	else \
		$(BILINECTL) plan reinstall dev --level $(REPAIR_LEVEL); \
		echo "Dry run only. Re-run with CONFIRM=1 to execute."; \
	fi

package-release:
	./scripts/build-release-pkg.sh

package-internal: package-release

diagnose-ime:
	$(BILINECTL) diagnose dev

diagnose-ime-dev:
	$(BILINECTL) diagnose dev

diagnose-ime-release:
	./scripts/diagnose-ime.sh release

diagnose-dev-apps:
	$(BILINECTL) diagnose dev

configure-aliyun-credentials:
	./scripts/configure-aliyun-credentials.sh configure

aliyun-credentials-status:
	./scripts/configure-aliyun-credentials.sh status

smoke-ime:
	@echo "Automated real-host smoke was removed. Stop here and ask the user to manually select BilineIME Dev, focus the host, type, and report the result."
	@exit 2

smoke-ime-aliyun:
	@echo "Automated real-host smoke was removed. Stop here and ask the user to manually verify Aliyun preview in the host."
	@exit 2

smoke-ime-release:
	@echo "Automated real-host smoke was removed. Stop here and ask the user to manually select the release input source, type in TextEdit, and report the result."
	@exit 2

verify-ime:
	./scripts/build-librime.sh
	swift test --filter 'InputControllerEventRouterTests|BilingualInputSessionTests|BilineRimeTests'
	$(MAKE) build-ime
	$(MAKE) install-ime
	@echo "Manual host verification required: stop here and ask the user to select BilineIME Dev, focus TextEdit, and type the requested cases."

format:
	swift-format format -i $$(find App Sources Tests -name '*.swift' -print)

verify: test build-ime build-ime-release
