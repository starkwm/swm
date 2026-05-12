VERSION_TMPL=Sources/Swm/Version.swift.tmpl
VERSION_FILE=Sources/Swm/Version.swift

build:
	@swift build

release: clean
	@swift build --configuration release --disable-sandbox

format:
	@swift format format -r -i Sources Tests Package.swift

lint:
	@swift format lint -r Sources Tests Package.swift

test:
	@swift test --parallel --enable-code-coverage --disable-xctest --quiet

clean:
	@swift package clean

bump_version:
	@sed 's/__VERSION__/$(NEW_VERSION)/g' $(VERSION_TMPL) > $(VERSION_FILE)

.DEFAULT_GOAL := build
.PHONY: build release format lint test clean bump_version
