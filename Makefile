PROJECT_NAME := BilineIME
SCHEME := BilineIME
DERIVED_DATA := build/DerivedData
CONFIGURATION ?= Debug

.PHONY: bootstrap project test build-ime install-ime package-internal format verify

bootstrap:
	brew install xcodegen swift-format

project:
	xcodegen generate

test:
	swift test

build-ime: project
	xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

install-ime:
	./scripts/install-ime-dev.sh

package-internal:
	./scripts/build-internal-pkg.sh

format:
	swift-format format -i $$(find App Sources Tests -name '*.swift' -print)

verify: test build-ime
