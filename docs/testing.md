# Testing

[Documentation index](index.md)

Run the complete suite after a change:

```sh
make test
```

This builds the current sources and runs Swift Testing in parallel. The socket
tests create temporary endpoints and do not require a running swm daemon.

## Focused iteration

Pass SwiftPM test options through `TEST_ARGS`. A filter selects suite or method
names, so you can keep the edit-build-test cycle focused on the code you changed:

```sh
make test TEST_ARGS='--filter SwmLibTests.TilingTests'
make test TEST_ARGS='--filter WindowFrameReconcilerTests/retainWindows'
```

After building, rerun the same binaries without the build check:

```sh
make test TEST_ARGS='--skip-build'
make test TEST_ARGS='--skip-build --filter SwmLibTests.TilingTests'
```

Use `--skip-build` only when sources have not changed since the last successful
build. Run the complete suite with a build before committing.

## Benchmarking

Measure wall time separately from the execution times reported by Swift Testing.
Warm the build once, then take several samples with the same toolchain and flags:

```sh
make test
for sample in 1 2 3 4 5; do
  /usr/bin/time -p make test
done
```

Repeat with `TEST_ARGS='--skip-build'` to measure runner startup and test execution
without SwiftPM's build check. For an edit-build-test measurement, make a small
edit to the relevant file before each sample. Compare medians, and run benchmarks
sequentially to avoid competition between samples.

The October 11, 2026 audit measured the following medians on arm64 macOS with
Apple Swift 6.4 in a debug build. Full and focused runs used five samples after
warming the build; edit-build-test runs used three temporary comment edits to
`TilingTests.swift`, restoring the file afterward. All full runs passed 319 tests
in 64 suites.

| Measurement | Before | After |
| --- | ---: | ---: |
| Full suite, warm build, wall time | 1.85 s | 1.52 s |
| Full suite, skip build, wall time | 1.41 s | 1.10 s |
| Reported execution time, summed across both test targets | 0.76 s | 0.50 s |
| Test-file edit, build, and full suite, wall time | 4.08 s | 3.96 s |
| Focused `WindowFrameReconcilerTests`, warm build, wall time | Not measured | 1.10 s |

Warm full-suite wall time fell about 18%. The edit-build-test ranges overlapped,
so the small difference there does not establish a build-time improvement.
Timings depend on hardware, cache state, and load.

For asynchronous tests, wait for an observable result or a worker-queue barrier
instead of a fixed delay. Keep the real polling interval when testing automatic
membership detection. Exercise related membership changes in one tick so the
test does not pay for an extra interval.
