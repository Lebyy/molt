.PHONY: build test install

build:
	swift build -c release -Xswiftc -warnings-as-errors

test: build
	.build/release/molt-selfcheck

install: build
	.build/release/molt install
