PROJECT_NAME := BilineIME
DEV_SCHEME := BilineIMEDev
RELEASE_SCHEME := BilineIME
DERIVED_DATA := $(HOME)/Library/Caches/BilineIME/DerivedData
CONFIGURATION ?= Debug

.PHONY: bootstrap project test build-ime build-ime-release install-ime uninstall-ime reset-ime repair-ime package-release package-internal diagnose-ime smoke-ime verify-ime format verify

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

install-ime:
	./scripts/install-ime-dev.sh

uninstall-ime:
	./scripts/uninstall-ime.sh

reset-ime:
	./scripts/uninstall-ime.sh
	./scripts/install-ime-dev.sh

repair-ime:
	./scripts/repair-ime.sh $(REPAIR_LEVEL)

package-release:
	./scripts/build-release-pkg.sh

package-internal: package-release

diagnose-ime:
	./scripts/diagnose-ime.sh

smoke-ime:
	./scripts/smoke-ime.sh prepare
	./scripts/smoke-ime.sh run

verify-ime:
	./scripts/build-librime.sh
	swift test --filter 'InputControllerEventRouterTests|BilingualInputSessionTests|BilineRimeTests'
	$(MAKE) build-ime
	$(MAKE) install-ime
	$(MAKE) smoke-ime

format:
	swift-format format -i $$(find App Sources Tests -name '*.swift' -print)

verify: test build-ime build-ime-release
