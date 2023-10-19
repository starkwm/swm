SRC=$(wildcard Sources/**/*.swift)

all: build

lint:
	@swiftlint lint --quiet

test:
	@swift test

clean:
	@swift package clean

build: $(SRC)
	@swift build

.PHONY: all lint test clean build
