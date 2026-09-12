# Microservices Architecture & API Design

## 1. Project Layout Specification

Adhere to standard Go project structure (`golang-standards/project-layout`) optimized for Domain-Driven Design (DDD) and Clean Architecture.

| Directory | Visibility | Purpose | Invariants |
| :--- | :--- | :--- | :--- |
| `/cmd/{app}` | Public | Application entrypoints (`main.go`) | Must contain only initialization and signal wiring logic; no business code. |
| `/internal/domain` | Private | Core entities, value objects, domain errors | Zero external dependencies; no database or transport code. |
| `/internal/ports` | Private | Primary/secondary interface definitions | Defines repository, service, and external client interfaces. |
| `/internal/adapters` | Private | Concrete implementations (DB, HTTP, gRPC) | Implements `/internal/ports` interfaces; handles serialization. |
| `/pkg/{module}` | Public | Reusable library code exported to external projects | Must be completely decoupled from application domain context. |
| `/api/v1` | Public | OpenAPI specs, Proto files (`.proto`), JSON schemas | Single source of truth for API contracts. |

---

## 2. Invariants & Guardrails

* **MUST** isolate domain logic (`/internal/domain`) from all transport frameworks (`net/http`, `gRPC`) and database drivers.
* **MUST** pass `context.Context` as the first argument in all service, repository, and IPC calls.
* **MUST** use signal-aware context cancellation with timeout limits during process termination.
* **NEVER** use global variables (`var db *sql.DB`) for application state or client instances; mandate explicit Dependency Injection via constructors (`NewService(...)`).
* **NEVER** leak raw database/ORM errors across API boundaries; map explicitly to domain errors, HTTP status codes, or gRPC status codes.
* **NEVER** import `/internal/...` packages across external Go modules.

---

## 3. Server Initialization & Graceful Shutdown

Dual HTTP/gRPC dual-stack entrypoint executing graceful termination upon `SIGINT`/`SIGTERM` via `golang.org/x/sync/errgroup`.

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"golang.org/x/sync/errgroup"
	"google.golang.org/grpc"
)

func main() {
	if err := run(context.Background()); err != nil && !errors.Is(err, http.ErrServerClosed) {
		fmt.Fprintf(os.Stderr, "server error: %v\n", err)
		os.Exit(1)
	}
}

func run(ctx context.Context) error {
	ctx, stop := signal.NotifyContext(ctx, os.Interrupt, syscall.SIGTERM)
	defer stop()

	g, ctx := errgroup.WithContext(ctx)

	// gRPC Server Setup
	grpcSrv := grpc.NewServer()
	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		return fmt.Errorf("failed to listen on :50051: %w", err)
	}

	g.Go(func() error {
		fmt.Println("gRPC server starting on :50051")
		return grpcSrv.Serve(lis)
	})

	g.Go(func() error {
		<-ctx.Done()
		fmt.Println("Shutting down gRPC server...")
		grpcSrv.GracefulStop()
		return nil
	})

	// HTTP Server Setup
	httpSrv := &http.Server{
		Addr:         ":8080",
		Handler:      http.NotFoundHandler(), // Replace with actual router
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	g.Go(func() error {
		fmt.Println("HTTP server starting on :8080")
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			return err
		}
		return nil
	})

	g.Go(func() error {
		<-ctx.Done()
		fmt.Println("Shutting down HTTP server...")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return httpSrv.Shutdown(shutdownCtx)
	})

	return g.Wait()
}
```

---

## 4. Middleware Composition Pattern

### Idiomatic HTTP Middleware
```go
type Middleware func(http.Handler) http.Handler

func Chain(h http.Handler, m ...Middleware) http.Handler {
	for i := len(m) - 1; i >= 0; i-- {
		h = m[i](h)
	}
	return h
}

func RequestIDMiddleware() Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			reqID := r.Header.Get("X-Request-ID")
			if reqID == "" {
				reqID = "generated-uuid" // Replace with actual UUID library
			}
			w.Header().Set("X-Request-ID", reqID)
			ctx := context.WithValue(r.Context(), "request_id", reqID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
```

### HTTP & gRPC Middleware Mapping Matrix

| Concern | HTTP Middleware Pattern | gRPC Interceptor Pattern |
| :--- | :--- | :--- |
| Logging / Tracing | Wrap `http.ResponseWriter` to record status code | `grpc.UnaryServerInterceptor` context extraction |
| Recovery | `recover()` defer block returning `500 Internal Server Error` | Catch panic, log stack trace, convert to `codes.Internal` |
| Auth | Header extraction -> Context injection -> Abort `401/403` | Metadata extraction -> Context injection -> Abort `codes.Unauthenticated` |
| Rate Limiting | Token bucket check -> Abort `429 Too Many Requests` | Token bucket check -> Abort `codes.ResourceExhausted` |

---

## 5. Domain Error Handling & Status Code Mapping

### Error Domain Interface
```go
package domain

import "errors"

var (
	ErrNotFound     = errors.New("entity not found")
	ErrUnauthorized = errors.New("unauthorized access")
	ErrConflict     = errors.New("resource conflict")
)

type DomainError struct {
	Err    error
	Detail string
}

func (e *DomainError) Error() string {
	return e.Err.Error() + ": " + e.Detail
}

func (e *DomainError) Unwrap() error {
	return e.Err
}
```

### Transport Mapping Table

| Sentinel Domain Error | HTTP Status Code | gRPC Status Code | Remediation Action |
| :--- | :--- | :--- | :--- |
| `ErrNotFound` | `404 Not Found` | `codes.NotFound` | Client verifies target resource identifier |
| `ErrUnauthorized` | `401 Unauthorized` | `codes.Unauthenticated` | Client refreshes token / re-authenticates |
| `ErrConflict` | `409 Conflict` | `codes.AlreadyExists` | Client resolves state divergence |
| `ErrInvalidInput` | `422 Unprocessable` | `codes.InvalidArgument` | Client corrects request payload validation |
| Unhandled Internal Err | `500 Internal Error` | `codes.Internal` | Server operator checks application traces/logs |

---

## 6. Constructor-Based Dependency Injection (Manual Wire)

Avoid complex DI reflection frameworks; leverage explicit constructor injection and interface segregation.

```go
package main

import "context"

// 1. Ports (Interfaces)
type UserRepository interface {
	GetUser(ctx context.Context, id string) (string, error)
}

// 2. Adapter Implementation
type PostgresUserRepo struct {
	dbConnString string
}

func NewPostgresUserRepo(connStr string) *PostgresUserRepo {
	return &PostgresUserRepo{dbConnString: connStr}
}

func (r *PostgresUserRepo) GetUser(ctx context.Context, id string) (string, error) {
	return "User:" + id, nil
}

// 3. Application Service
type UserService struct {
	repo UserRepository
}

func NewUserService(repo UserRepository) *UserService {
	return &UserService{repo: repo}
}

// 4. Initialization Wiring
func WireApplication() *UserService {
	repo := NewPostgresUserRepo("postgres://localhost:5432/db")
	return NewUserService(repo)
}
```
