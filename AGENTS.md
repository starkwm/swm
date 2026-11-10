# swm

macOS window manager (Swift 6, macOS 26+). One `swm` process runs as a daemon; other invocations send commands to it over IPC.

## Layout

- `Sources/Swm`: CLI executable (swift-argument-parser commands).
- `Sources/SwmLib`: daemon logic (`Configuration`, `IPC`, `Platform`, `Runtime`, `Support`). Links the private SkyLight framework.
- `Tests/SwmLibTests`, `Tests/SwmTests`: Swift Testing suites.
- `docs/`: user documentation. Update it when command behavior or syntax changes.

## Commands

- `make build`
- `make test` (filter with `make test TEST_ARGS='--filter SwmLibTests.TilingTests'`)
- `make format` / `make lint` (swift-format, 2-space indent)

Run `make lint` and the full `make test` before committing. Tests must not require a running daemon or Accessibility permission.

## Conventions

- Commit messages are plain imperative sentences, not conventional commits.
- To bump the version, edit the string in `Sources/Swm/Version.swift` (e.g. `v0.0.33`).
