# Ghosium Performance

## Policy

Ghosium performance work is measurement-driven. Startup, shutdown, RAM or CPU improvements are not claimed until the exact source-built product is measured with the repository benchmark methodology.

Performance changes must not weaken:

- sandboxing;
- renderer/site isolation;
- TLS or certificate validation;
- extension trust verification;
- update hash/signature/publisher verification.

Ghosium does not cap renderer processes simply to report a smaller RAM number.

## 0.1.2 source defaults

Ghosium 0.1.2 introduces two conservative defaults using native engine mechanisms.

### Memory Saver

The engine's native Memory Saver state defaults to **enabled** for profiles that have not explicitly selected a state.

Ghosium intentionally preserves:

- native medium aggressiveness;
- the existing native discard threshold;
- native tab-freezing behavior;
- explicit user preferences and exceptions.

This means an existing user who deliberately selected another state is not overwritten by the distribution default.

### Background residency

The Windows build uses:

```text
enable_background_mode = false
```

This disables the legacy background-app keep-alive mode so closing the final browser window does not intentionally leave that mode resident. It does not disable the renderer sandbox, site isolation, certificate validation or normal web/service-worker behavior.

## Benchmark baseline

The repository retains an immutable historical Windows baseline under `benchmarks/windows/` and verifies the historical Setup hash before executing it.

The benchmark harness records:

- cold launch to first usable window;
- warm launch to first usable window;
- process count;
- working-set/private/paged memory;
- handles;
- normalized CPU during idle sampling;
- process disk-transfer counters;
- active TCP connection count;
- one-, five- and ten-tab scenarios;
- memory after a one-minute idle interval.

The historical hosted reference measured approximately:

```text
cold startup     867 ms
warm startup     282 ms
1 tab private    238 MiB
1 tab after idle 197 MiB
5 tabs private   328 MiB
10 tabs private  425 MiB
```

These figures are a CI-runner control reference, not universal desktop performance guarantees.

## Missing measurements

The current benchmark does not claim reliable per-process GPU-memory attribution or network byte attribution. These values should remain explicitly unclaimed until the harness can collect them reproducibly on the production Windows builder.

## Release performance gate

A production performance comparison requires:

1. successful full-source 0.1.2 compile;
2. exact canonical installed Ghosium binary;
3. comparable host/methodology;
4. recorded benchmark JSON and provenance;
5. no security boundary disabled for the measurement.

Until those conditions are met, Memory Saver/background-residency changes are described as **implemented defaults**, not as proven speed/RAM percentage improvements.
