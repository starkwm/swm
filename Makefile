SRC=$(wildcard Sources/**/*.swift)

all: build

lint:
	swiftlint lint --quiet

format:
	swiftformat --quiet Package.swift Sources/**/* Tests/**/*

test:
	swift test

clean:
	swift package clean

build: $(SRC)
	swift build

.PHONY: all lint format test clean build
