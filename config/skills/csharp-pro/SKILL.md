---
name: csharp-pro
description: Master modern C# 12/13 and .NET 8/9/10 engineering. Covers high-performance memory management (Span, Memory, ArrayPool), concurrency (Channels, async streams), primary constructors, pattern matching, records, source generators, and enterprise SOLID architecture. Use when writing C# code, refactoring .NET applications, or optimizing performance.
---

# Modern C# & .NET Engineering Guide

Enterprise-grade guide for writing modern, high-performance, and type-safe C# applications using the latest capabilities of C# 12/13 and .NET 8/9/10.

---

## Core .NET Engineering Directives

- **Strict Nullable Reference Types:** Always enable `<Nullable>enable</Nullable>`. Never suppress null warnings with `!` without rigorous assertion.
- **Zero-Allocation Hot Paths:** Use `ReadOnlySpan<char>`, `Span<T>`, and `ValueTask` in high-throughput hot paths (parsers, serializers, middleware) to minimize GC pressure.
- **Defensive Asynchrony:** Always accept and forward `CancellationToken` in public async APIs. Configure `.ConfigureAwait(false)` in non-UI class libraries.
- **Validate Options at Startup:** Use `services.AddOptions<T>().BindConfiguration(...).ValidateDataAnnotations().ValidateOnStart()` to fail fast on invalid configuration.

---

## 1. Modern C# 12/13 Idiomatic Patterns

### 1.1 Primary Constructors & Immutable Records
```csharp
// Clean domain entity with primary constructor and immutable properties
public sealed record Order(
    Guid Id,
    CustomerId CustomerId,
    Money TotalAmount,
    OrderStatus Status,
    DateTimeOffset CreatedAt)
{
    // Business invariant validation in constructor body
    public Order
    {
        ArgumentNullException.ThrowIfNull(CustomerId);
        ArgumentNullException.ThrowIfNull(TotalAmount);
    }
}

// Service with Primary Constructor Dependency Injection
public sealed class OrderProcessingService(
    IOrderRepository orderRepository,
    IPaymentGateway paymentGateway,
    ILogger<OrderProcessingService> logger) : IOrderProcessingService
{
    public async Task<Result<Order>> ProcessAsync(Guid orderId, CancellationToken ct = default)
    {
        logger.LogInformation("Processing order {OrderId}", orderId);
        var order = await orderRepository.GetByIdAsync(orderId, ct);
        if (order is null)
            return Result.Failure<Order>("Order not found");

        var paymentResult = await paymentGateway.ChargeAsync(order.TotalAmount, ct);
        if (!paymentResult.IsSuccess)
            return Result.Failure<Order>(paymentResult.Error);

        var updatedOrder = order with { Status = OrderStatus.Paid };
        await orderRepository.UpdateAsync(updatedOrder, ct);
        return Result.Success(updatedOrder);
    }
}
```

### 1.2 Collection Expressions & Pattern Matching
```csharp
public static class OrderEvaluator
{
    // Collection expressions (C# 12) with spread operator
    private static readonly int[] BaseTiers = [10, 20, 50];
    private static readonly int[] AllTiers = [..BaseTiers, 100, 200];

    // Exhaustive pattern matching with guards
    public static decimal CalculateDiscount(Customer customer, Order order) => (customer, order) switch
    {
        { IsVip: true, LoyaltyYears: > 5 } => 0.25m,
        { IsVip: true } or { TotalSpent: > 1000m } => 0.15m,
        (_, { TotalAmount.Value: > 500m }) => 0.10m,
        _ => 0.0m
    };
}
```

---

## 2. High-Performance Memory & Zero-Allocation Patterns

```csharp
using System.Buffers;

public static class FastLogParser
{
    // Zero-allocation string parsing using Span<char>
    public static bool TryParseLogLine(ReadOnlySpan<char> line, out ReadOnlySpan<char> level, out ReadOnlySpan<char> message)
    {
        level = default;
        message = default;

        if (line.IsEmpty || !line.StartsWith("["))
            return false;

        var closeBracket = line.IndexOf(']');
        if (closeBracket == -1)
            return false;

        level = line.Slice(1, closeBracket - 1);
        message = line.Slice(closeBracket + 1).TrimStart();
        return true;
    }

    // Renting buffers for high-throughput batch operations
    public static async Task ProcessStreamAsync(Stream stream, Func<byte[], int, Task> handleChunk)
    {
        var pool = ArrayPool<byte>.Shared;
        byte[] buffer = pool.Rent(4096);
        try
        {
            int bytesRead;
            while ((bytesRead = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length))) > 0)
            {
                await handleChunk(buffer, bytesRead);
            }
        }
        finally
        {
            pool.Return(buffer);
        }
    }
}
```

---

## 3. High-Throughput Concurrency with `System.Threading.Channels`

```csharp
using System.Threading.Channels;

public sealed class BackgroundQueue<T>
{
    private readonly Channel<T> _channel = Channel.CreateBounded<T>(new BoundedChannelOptions(1000)
    {
        FullMode = BoundedChannelFullMode.Wait,
        SingleReader = true,
        SingleWriter = false
    });

    public ValueTask EnqueueAsync(T item, CancellationToken ct = default) =>
        _channel.Writer.WriteAsync(item, ct);

    public IAsyncEnumerable<T> ReadAllAsync(CancellationToken ct = default) =>
        _channel.Reader.ReadAllAsync(ct);
}
```

---

## 4. ⚠️ Production Sharp Edges & Solutions

| Issue / Anti-Pattern | Severity | Root Cause | Production Solution |
| :--- | :--- | :--- | :--- |
| **Sync-Over-Async (`.Result`, `.Wait()`)** | 🔴 Critical | Thread pool starvation & deadlocks | Use `await` end-to-end; never block on `Task`. |
| **Swallowed Exceptions in `async void`** | 🔴 Critical | Unhandled crash breaks the process | Never use `async void` except in event handlers; use `async Task`. |
| **Large Object Heap (LOH) Fragmentation** | 🟡 High | Allocating byte arrays >85,000 bytes | Rent from `ArrayPool<byte>.Shared` or use `RecyclableMemoryStream`. |
| **Missing `CancellationToken` Forwarding** | 🟡 High | Leaking background orphaned tasks | Always pass `ct` to database and HTTP client calls. |
| **Boxing Value Types** | 🟡 Medium | Passing `struct` to non-generic interfaces | Use generic constraints `where T : struct` or `IEquatable<T>`. |
