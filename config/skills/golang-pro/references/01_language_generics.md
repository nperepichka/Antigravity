# Language Features & Generics

Activate this skill when designing modern Go 1.21+ systems requiring compile-time type safety via generics, high-performance structured logging, standard collections manipulation, or custom type constraints.

## 1. Modern Go 1.21+ Standard Utilities

### Core Built-Ins (Go 1.21+)
| Built-in | Signature | Purpose / Behavior |
| :--- | :--- | :--- |
| `min(x, y ...T)` | `min[T cmp.Ordered](x T, y ...T) T` | Returns the smallest value. Operates at compile-time for constants. |
| `max(x, y ...T)` | `max[T cmp.Ordered](x T, y ...T) T` | Returns the largest value. |
| `clear(m/s)` | `clear[T ~map[K]V](m T)` / `clear[T ~[]E](s T)` | Maps: deletes all keys (length becomes 0). Slices: sets elements to zero-value (retains length). |

### Slices, Maps, and Cmp Packages
| Package | Function Signature | Description & Critical Nuance |
| :--- | :--- | :--- |
| `slices` | `func Clone[S ~[]E, E any](s S) S` | Performs a shallow copy of the slice. |
| `slices` | `func Compact[S ~[]E, E comparable](s S) S` | Replaces consecutive runs of equal elements with a single copy. |
| `slices` | `func Delete[S ~[]E, E any](s S, i, j int) S` | Removes elements `s[i:j]`. **Warning**: Does not zero out remaining elements; can cause memory leaks with pointers. |
| `slices` | `func SortFunc[S ~[]E, E any](x S, cmp func(a, b E) int)` | Sorts slice using custom comparator function. Use with `cmp.Compare`. |
| `maps` | `func Copy[M1 ~map[K]V, M2 ~map[K]V, K comparable, V any](dst M1, src M2)` | Copies all key/value pairs from `src` to `dst`. |
| `maps` | `func DeleteFunc[M ~map[K]V, K comparable, V any](m M, del func(K, V) bool)` | Deletes any key/value pairs matching the predicate. |
| `cmp` | `func Compare[T Ordered](x, y T) int` | Returns `-1` if `x < y`, `0` if `x == y`, `+1` if `x > y`. Handled via compiler intrinsics. |

---

## 2. Generics & Type Constraints

### Standard Type Constraints (`golang.org/x/exp/constraints` or native equivalents)
```go
type Number interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64 | ~float32 | ~float64
}
```
*Note: The approximation tilde `~` allows the constraint to match underlying types (e.g., `type MyInt int`).*

### Invariants & Guardrails
*   **NO Generic Struct Methods**: Go does not support generic methods on structs. Methods can only use type parameters declared on the receiver struct. If a method requires a new type parameter, it must be written as a standalone package-level function.
*   **Interface Restriction**: Type parameters cannot be used in type assertions directly. Use standard interfaces if runtime type assertion is required.
*   **Zero-Value Initialization**: To obtain the zero-value of a type parameter `T`, use `var zero T` or return `*new(T)` if returning a pointer.

### Canonical Pattern: Concurrent Type-Safe Cache
```go
package cache

import (
	"sync"
)

type Cache[K comparable, V any] struct {
	mu sync.RWMutex
	dm map[K]V
}

func New[K comparable, V any]() *Cache[K, V] {
	return &Cache[K, V]{dm: make(map[K]V)}
}

func (c *Cache[K, V]) Get(key K) (V, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	val, ok := c.dm[key]
	return val, ok
}

func (c *Cache[K, V]) Set(key K, val V) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.dm[key] = val
}
```

---

## 3. Structured Logging with `log/slog`

Structured logging must optimize for allocations while propagating context trace IDs cleanly.

### Execution Paradigms & APIs
| Feature | Code API | Best Practice / Performance Impact |
| :--- | :--- | :--- |
| **JSON Formatting** | `slog.NewJSONHandler(os.Stdout, nil)` | Mandatory for cloud production. Zeroes out log parsing overhead. |
| **Context Logging** | `logger.InfoContext(ctx, msg, args...)` | Must be used in microservices to pull request/trace IDs from context. |
| **Pre-allocation** | `logger.With(slog.String("svc", "api"))` | Use for thread/request lifecycles. Avoids repeating common keys. |
| **Valuer Interface** | Implement `slog.LogValuer` | Allows custom types to marshal safely or mask sensitive fields. |

### Canonical Pattern: Context-Aware Trace Logging Handler
```go
package logger

import (
	"context"
	"io"
	"log/slog"
)

type contextKey string
const TraceKey contextKey = "trace_id"

type TraceHandler struct {
	slog.Handler
}

func NewTraceHandler(w io.Writer, opts *slog.HandlerOptions) *TraceHandler {
	return &TraceHandler{Handler: slog.NewJSONHandler(w, opts)}
}

func (h *TraceHandler) Handle(ctx context.Context, r slog.Record) error {
	if ctx != nil {
		if traceID, ok := ctx.Value(TraceKey).(string); ok {
			r.AddAttrs(slog.String("trace_id", traceID))
		}
	}
	return h.Handler.Handle(ctx, r)
}
```

---

## 4. Anti-Patterns & Resolution

*   **Anti-Pattern**: Using `slices.Delete` without cleaning up pointers, causing memory retention/leaks of omitted struct pointers.
    *   *Correction*: Manually zero out index elements if elements contain pointer values before applying `slices.Delete`.
*   **Anti-Pattern**: Dynamically instantiating generic handlers inside critical request loops, triggering massive garbage collector allocations.
    *   *Correction*: Instantiate generic structs and reference types once globally or inside initialization setups.
*   **Anti-Pattern**: Passing plain interfaces into `slog` arguments without typed attributes, causing heavy allocation overheads through boxing.
    *   *Correction*: Use concrete types with fast-path attributes like `slog.Int64()`, `slog.String()`, and `slog.Duration()` instead of generic `slog.Any()`.
