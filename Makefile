VERSION_TMPL=Sources/Swm/Version.swift.tmpl
VERSION_FILE=Sources/Swm/Version.swift
TEST_ARGS ?=

build:
	@swift build

release:
	@swift build --configuration release --disable-sandbox

format:
	@swift format format -r -i Sources Tests Package.swift

lint:
	@swift format lint -r Sources Tests Package.swift

test:
	@swift test --parallel --disable-xctest $(TEST_ARGS)

clean:
	@swift package clean

bump_version:
	@sed 's/__VERSION__/$(NEW_VERSION)/g' $(VERSION_TMPL) > $(VERSION_FILE)

.DEFAULT_GOAL := build
.PHONY: build release format lint test smoke clean bump_version
