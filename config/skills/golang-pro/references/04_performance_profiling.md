# Performance Optimization & Profiling

Activate this skill when optimizing execution latency, reducing heap allocations, investigating memory leaks, profiling CPU usage, executing micro-benchmarks, tuning the Garbage Collector (GC), or capturing runtime traces.

## 1. Diagnostic & Profiling Toolchain

### Profiling Commands & Endpoints

| Command / Endpoint | Type | Purpose | Production Safety |
| :--- | :--- | :--- | :--- |
| `go test -bench=. -benchmem` | CLI | Run micro-benchmarks with allocation stats | Safe (Local only) |
| `go tool pprof -http=:8080 cpu.prof` | CLI | Interactive visualization of CPU profile | Safe |
| `go tool trace trace.out` | CLI | Timeline view of scheduler events, GC, & network | High overhead (Short capture only) |
| `/debug/pprof/profile?seconds=30` | HTTP | Download 30s CPU profile | Safe (~1-5% CPU overhead) |
| `/debug/pprof/heap` | HTTP | Query active/allocated heap memory | Safe |
| `/debug/pprof/allocs` | HTTP | Query all allocations since process start | Safe |
| `/debug/pprof/block` | HTTP | Query goroutine blocking on synchronization | Requires `runtime.SetBlockProfileRate` |
| `/debug/pprof/mutex` | HTTP | Query lock contention profile | Requires `runtime.SetMutexProfileFraction` |

### Compilation Diagnostics & Optimization Flags

| Compiler Flag | Diagnostic / Optimization Target |
| :--- | :--- |
| `go build -gcflags="-m"` | Prints escape analysis decisions and inlining candidates |
| `go build -gcflags="-m=2"` | Emits verbose, multi-level escape analysis details |
| `go build -gcflags="-asmdump"` | Dumps generated assembly instructions |
| `go build -pgo=default.pgo` | Profile-Guided Optimization (PGO) using production CPU profile (2-7% perf boost) |
| `go build -ldflags="-s -w"` | Strips DWARF debug symbols and symbol table (~25-40% smaller binary size) |

---

## 2. Invariants & Guardrails

- **Rule 1: Profile First.** Never perform optimizations based on intuition or heuristics. Base every architectural change on differential profiles (`pprof -diff_base`).
- **Rule 2: Reset Timer.** Always invoke `b.ResetTimer()` inside micro-benchmarks if setup work (allocations, IO) occurs prior to the loop.
- **Rule 3: Pin sync.Pool Types.** Every object put into a `sync.Pool` must be of identical underlying type. Never store different structural types in a single pool unless wrapped in an interface (creates runtime allocation).
- **Rule 4: Reset Pooled State.** Slice capacities and structures retrieved from a `sync.Pool` *must* be fully zeroed or reset before reuse to avoid leaking data across calls.
- **Rule 5: Watch GOMEMLIMIT.** Never set `GOMEMLIMIT` without leaving a 10-15% safety buffer below the hard container/node memory limit to avoid aggressive GC thrashing or immediate OOM-kills.

---

## 3. Canonical Code Patterns

### Idiomatic Micro-benchmarking

```go
package perf

import "testing"

func BenchmarkProcessData(b *testing.B) {
	// Expensive initialization goes here
	input := make([]byte, 1024)
	b.ReportAllocs()
	b.ResetTimer() // Exclude initialization overhead

	for i := 0; i < b.N; i++ {
		_ = Process(input)
	}
}
```

### High-Performance `sync.Pool` Pattern

```go
package perf

import "sync"

type Buffer struct {
	Data []byte
}

func (b *Buffer) Reset() {
	b.Data = b.Data[:0]
}

var bufPool = sync.Pool{
	New: func() any {
		// Allocate with predefined capacity to prevent intermediate growths
		return &Buffer{Data: make([]byte, 0, 1024)}
	},
}

func ExecutePooledWork(input []byte) {
	buf := bufPool.Get().(*Buffer)
	defer func() {
		buf.Reset()
		bufPool.Put(buf)
	}()

	buf.Data = append(buf.Data, input...)
	// Execute critical path operations utilizing buf.Data
}
```

### Zero-Allocation String-to-Byte-Slice Conversions (Go 1.20+)

```go
package perf

import (
	"unsafe"
)

// StringToBytes converts a string to a byte slice without allocation.
// Read-only invariant: Modification of the returned slice yields undefined behavior/segmentation fault.
func StringToBytes(s string) []byte {
	if s == "" {
		return nil
	}
	return unsafe.Slice(unsafe.StringData(s), len(s))
}

// BytesToString converts a byte slice to a string without allocation.
func BytesToString(b []byte) string {
	if len(b) == 0 {
		return ""
	}
	return unsafe.String(unsafe.SliceData(b), len(b))
}
```

---

## 4. GC Tuning & Memory Management Runtime Controls

| Environment Variable | Unit / Options | Default | Operational Impact |
| :--- | :--- | :--- | :--- |
| `GOGC` | Percentage | `100` | Controls target heap size increment relative to live heap. Higher values delay GC, increasing throughput at the expense of memory footprint. `off` disables GC. |
| `GOMEMLIMIT` | Bytes (e.g., `2GiB`, `2048MiB`) | Off | Hard ceiling for total runtime memory. Triggers garbage collection proactively as the limit is approached, overriding GOGC target paths to prevent OOM termination. |
| `GODEBUG` | `gctrace=1` | Off | Emits summary trace outputs to stderr on every GC cycle showing heap sizes, target limits, sweep phases, and pause times. |
