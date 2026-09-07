# Ghosium performance benchmarks

Performance work in Ghosium is measurement-driven. A change is not described as faster or lighter merely because code was removed, a flag was added, or a synthetic micro-benchmark improved.

## Canonical pre-0.1.0 reference

`windows/v0.8.0-hosted-baseline.json` is the immutable historical comparison reference for the old public `v0.8.0` Windows package. The Setup executable was downloaded from the historical release and verified against its exact SHA-256 before execution.

The baseline records:

- cold and warm launch to the first usable browser window;
- aggregate working set and private memory;
- one-, five- and ten-tab scenarios;
- one-minute idle memory for the one-tab scenario;
- process and handle counts;
- normalized idle CPU;
- disk transfer counters and active TCP connection count in the raw CI artifact.

## Comparison rules

A Ghosium 0.1.x result may be compared with the historical baseline only when:

1. the same benchmark harness and page workload are used;
2. the Windows runner conditions are materially comparable;
3. the tested executable is identified by version and build provenance;
4. profile isolation is enabled;
5. no security boundary such as sandboxing, certificate validation or site isolation is disabled to improve a number;
6. both regressions and improvements are reported.

A hosted-runner measurement is not a universal claim about every Windows PC. Cold startup here means a fresh browser profile with no Ghosium processes running; the OS filesystem cache is not forcibly flushed.

## Metrics not yet claimed

The current harness intentionally does not claim reliable per-process GPU memory or byte-level network attribution. Those metrics require a separately reviewed implementation before they are used as release claims.

## Release use

The full-source 0.1.x build must first pass source verification, compilation, runtime smoke testing and installer round-trip verification. Only then should the same benchmark harness be run against that exact source-built artifact and compared with the historical reference.
