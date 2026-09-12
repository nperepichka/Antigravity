---
name: golang-pro
description: Master Go 1.21+ software development, advanced concurrency
  patterns, production microservice architecture, and runtime performance
  optimization. Use this skill when building Go microservices or CLIs,
  implementing concurrent pipelines and worker pools, profiling latency/memory
  allocations, or auditing Go codebase architecture.
---

# golang-pro

Master Go 1.21+ software development, advanced concurrency patterns, production microservice architecture, and runtime performance optimization. Use this skill when building Go microservices or CLIs, implementing concurrent pipelines and worker pools, profiling latency/memory allocations, or auditing Go codebase architecture.

## Context Trigger Matrix

| Sub-module | Context Trigger / Keywords | File Path |
| :--- | :--- | :--- |
| Language Features & Generics | `generics`, `go 1.21`, `cmp`, `slices`, `maps`, `type parameters`, `slog` | [01_language_generics.md](./references/01_language_generics.md) |
| Advanced Concurrency Patterns | `goroutines`, `channels`, `worker pools`, `errgroup`, `context`, `sync.Mutex`, `race condition` | [02_concurrency_patterns.md](./references/02_concurrency_patterns.md) |
| Microservices Architecture & API Design | `project layout`, `grpc`, `http`, `middleware`, `graceful shutdown`, `dependency injection`, `domain-driven design` | [03_microservices_architecture.md](./references/03_microservices_architecture.md) |
| Performance Optimization & Profiling | `pprof`, `benchmarking`, `memory allocation`, `zero-alloc`, `gc tuning`, `sync.Pool`, `trace` | [04_performance_profiling.md](./references/04_performance_profiling.md) |

## Quickstart & Canonical Setup

```go
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"golang.org/x/sync/errgroup"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	g, ctx := errgroup.WithContext(ctx)
	jobs := make(chan int, 10)

	g.Go(func() error {
		defer close(jobs)
		for i := 1; i <= 5; i++ {
			select {
			case <-ctx.Done():
				return ctx.Err()
			case jobs <- i:
			}
		}
		return nil
	})

	for w := 1; w <= 3; w++ {
		wID := w
		g.Go(func() error {
			for job := range jobs {
				select {
				case <-ctx.Done():
					return ctx.Err()
				default:
					slog.Info("processing job", "worker", wID, "job", job)
					time.Sleep(50 * time.Millisecond)
				}
			}
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		slog.Error("execution failed", "error", err)
	}
}
```
