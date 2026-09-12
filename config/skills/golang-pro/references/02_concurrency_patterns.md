# Advanced Concurrency Patterns

Provides architectural patterns, lifecycle management, synchronization primitives, and anti-pattern guardrails for production-grade Go concurrency.

## Synchronization & Concurrency Primitives

| Primitive | Use Case | Allocation Overhead | Edge Cases / Traps |
| :--- | :--- | :--- | :--- |
| `chan T` (Unbuffered) | Strict handoff, point-to-point sync | Minimal (`hchan`) | Blocks sender until receiver is ready. Deadlock on unreceived write. |
| `chan T` (Buffered) | Async messaging, decoupling throughput | Medium (`hchan` + buffer) | Sends block when full; receives block when empty. Panic on write to closed channel. |
| `sync.Mutex` | Mutual exclusion over shared state | 24 bytes (`Locker`) | Non-reentrant. Double lock causes immediate deadlock. Must defer unlock. |
| `sync.RWMutex` | Read-heavy shared state | 24 bytes + reader state | Writers block readers. Reader starvation if writes are continuous. |
| `sync.WaitGroup` | Waiting for collection of goroutines | 12/16 bytes | Negative counter causes panic. Re-using before `Wait()` completes causes race. |
| `sync.Map` | Read-heavy or disjoint key space | High (interface allocations) | Slow for write-heavy workloads. Prefer sharded map for frequent writes. |
| `errgroup.Group` | Parallel execution with error propagation | Low | `g.Go` after `g.Wait` panics. `SetLimit` blocks when worker limit reached. |
| `semaphore.Weighted` | Fine-grained resource concurrency | Low | Releasing more tokens than acquired panics. Respect context deadline on `Acquire`. |

## Core Invariants & Anti-Patterns

- **Sender Closes Channels**: NEVER close a channel from the receiving side or when multiple senders exist. Closing a closed channel panics.
- **Goroutine Leak Prevention**: NEVER launch a goroutine without an explicit exit condition (context termination, channel close, or frame return).
- **Lock Scoping & Copying**: NEVER copy a `sync.Mutex` or structs containing synchronization primitives. Always pass by pointer.
- **Race Detector Compliance**: MUST pass `go test -race ./...` in CI. Zero tolerance for memory races.
- **Context Propagation**: MUST pass `context.Context` as the first argument to concurrent functions and check `ctx.Done()` in loop steps.
- **Loop Variable Capture**: In Go < 1.22, local variables in `for` loops must be re-bound locally inside goroutine closures to avoid race conditions.

## Production Concurrency Patterns

### 1. Worker Pool with Context Cancellation & Graceful Drain

```go
type Job struct { ID int; Payload string }
type Result struct { JobID int; Output string; Err error }

func WorkerPool(ctx context.Context, workers int, jobs <-chan Job) <-chan Result {
    results := make(chan Result, workers)
    var wg sync.WaitGroup

    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range jobs {
                select {
                case <-ctx.Done():
                    results <- Result{JobID: job.ID, Err: ctx.Err()}
                    return
                case results <- process(job):
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### 2. Fan-Out / Fan-In Pipeline

```go
func Generate(ctx context.Context, nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for _, n := range nums {
            select {
            case <-ctx.Done(): return
            case out <- n:
            }
        }
    }()
    return out
}

func Merge[T any](ctx context.Context, channels ...<-chan T) <-chan T {
    var wg sync.WaitGroup
    out := make(chan T)
    output := func(c <-chan T) {
        defer wg.Done()
        for v := range c {
            select {
            case <-ctx.Done(): return
            case out <- v:
            }
        }
    }
    wg.Add(len(channels))
    for _, c := range channels { go output(c) }
    go func() { wg.Wait(); close(out) }()
    return out
}
```

### 3. ErrGroup with Concurrency Limit & Timeout

```go
func ParallelFetch(ctx context.Context, urls []string, limit int) ([]string, error) {
    g, ctx := errgroup.WithContext(ctx)
    g.SetLimit(limit)
    res := make([]string, len(urls))

    for i, url := range urls {
        i, url := i, url
        g.Go(func() error {
            req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
            if err != nil { return err }
            resp, err := http.DefaultClient.Do(req)
            if err != nil { return err }
            defer resp.Body.Close()
            res[i] = resp.Status
            return nil
        })
    }
    if err := g.Wait(); err != nil { return nil, err }
    return res, nil
}
```

### 4. Low-Contention Sharded Concurrent Map

```go
type ShardedMap[V any] struct {
    shards []*shard[V]
    mask   uint32
}

type shard[V any] struct {
    sync.RWMutex
    data map[string]V
}

func NewShardedMap[V any](shardCountExponent uint32) *ShardedMap[V] {
    size := 1 << shardCountExponent
    sm := &ShardedMap[V]{shards: make([]*shard[V], size), mask: uint32(size - 1)}
    for i := range sm.shards {
        sm.shards[i] = &shard[V]{data: make(map[string]V)}
    }
    return sm
}

func (m *ShardedMap[V]) getShard(key string) *shard[V] {
    var h uint32 = 2166136261
    for i := 0; i < len(key); i++ {
        h = (h ^ uint32(key[i])) * 16777619
    }
    return m.shards[h&m.mask]
}

func (m *ShardedMap[V]) Get(key string) (V, bool) {
    s := m.getShard(key)
    s.RLock()
    defer s.RUnlock()
    v, ok := s.data[key]
    return v, ok
}

func (m *ShardedMap[V]) Set(key string, val V) {
    s := m.getShard(key)
    s.Lock()
    s.data[key] = val
    s.Unlock()
}
```

## Diagnostics & Race Detection Matrix

| Issue | Manifestation | Detection CLI | Mitigation |
| :--- | :--- | :--- | :--- |
| Data Race | Concurrent read/write to shared var | `go test -race ./...` | Mutex, atomic (`sync/atomic`), or channel passing |
| Goroutine Leak | Unbound memory growth, leaked sockets | `pprof` (goroutine profile) | Ensure context cancellation or buffered exit channels |
| Deadlock | Program hangs permanently | `SIGQUIT` dump / runtime panic | Enforce strict lock ordering; add `select` timeouts |
| Lock Contention | High CPU overhead, latency spikes | `go test -bench . -blockprofile` | Split locks, use `sync.RWMutex`, or sharded map |
