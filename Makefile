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

.DEFAULT_GOAL := build
.PHONY: build release format lint test clean
