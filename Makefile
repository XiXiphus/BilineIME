PROJECT_NAME := BilineIME
DEV_SCHEME := BilineIMEDev
RELEASE_SCHEME := BilineIME
SETTINGS_SCHEME := BilineSettingsDev
DERIVED_DATA := $(HOME)/Library/Caches/BilineIME/DerivedData
CONFIGURATION ?= Debug

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
	./scripts/install-settings-dev.sh

install-ime:
	./scripts/install-ime-dev.sh

uninstall-ime:
	./scripts/uninstall-ime.sh

reset-ime:
	./scripts/uninstall-ime.sh
	./scripts/install-ime-dev.sh

reset-dev-apps:
	./scripts/reset-dev-apps.sh

repair-ime:
	./scripts/repair-ime.sh $(REPAIR_LEVEL)

package-release:
	./scripts/build-release-pkg.sh

package-internal: package-release

diagnose-ime:
	./scripts/diagnose-ime.sh dev

diagnose-ime-dev:
	./scripts/diagnose-ime.sh dev

diagnose-ime-release:
	./scripts/diagnose-ime.sh release

diagnose-dev-apps:
	./scripts/diagnose-dev-apps.sh

configure-aliyun-credentials:
	./scripts/configure-aliyun-credentials.sh configure

aliyun-credentials-status:
	./scripts/configure-aliyun-credentials.sh status

smoke-ime:
	./scripts/smoke-ime.sh prepare
	./scripts/smoke-ime.sh run

smoke-ime-aliyun:
	./scripts/smoke-ime.sh prepare
	./scripts/smoke-ime.sh aliyun

smoke-ime-release:
	TARGET_SOURCE_ID=io.github.xixiphus.inputmethod.BilineIME.pinyin APP_PROCESS=BilineIME SMOKE_DEFAULTS_DOMAIN=io.github.xixiphus.inputmethod.BilineIME SMOKE_DISPLAY_NAME=BilineIME ./scripts/smoke-ime.sh prepare
	TARGET_SOURCE_ID=io.github.xixiphus.inputmethod.BilineIME.pinyin APP_PROCESS=BilineIME SMOKE_DEFAULTS_DOMAIN=io.github.xixiphus.inputmethod.BilineIME SMOKE_DISPLAY_NAME=BilineIME ./scripts/smoke-ime.sh run

verify-ime:
	./scripts/build-librime.sh
	swift test --filter 'InputControllerEventRouterTests|BilingualInputSessionTests|BilineRimeTests'
	$(MAKE) build-ime
	$(MAKE) install-ime
	$(MAKE) smoke-ime

format:
	swift-format format -i $$(find App Sources Tests -name '*.swift' -print)

verify: test build-ime build-ime-release
