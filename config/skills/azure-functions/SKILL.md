---
name: azure-functions
description: Expert patterns for Azure Functions development including .NET Isolated Worker model, Node.js v4 TypeScript model, Python v2 decorators, Durable Functions orchestration, bindings, and cold start optimization. Use when building serverless APIs, event-driven worker functions, or orchestrating workflows on Azure.
---

# Azure Functions Engineering Guide

Production-grade development guide for building resilient, scalable, and cost-effective serverless applications on Azure Functions across **.NET Isolated Worker**, **Node.js v4 (TypeScript)**, and **Python v2**.

---

## Core Principles & Execution Models

- **Always Use Isolated Worker Model for .NET:** The in-process model is deprecated in .NET 8+. The isolated model provides full control over `Program.cs`, dependency injection, middleware pipelines, and independent framework versioning.
- **Node.js v4 & Python v2 Code-Centric Models:** Use modern code-based definitions (`app.http(...)` / `@app.route(...)`) instead of legacy `function.json` files.
- **Connection Management:** Never instantiate `new HttpClient()` per invocation. Use `IHttpClientFactory` (.NET) or module-level singleton clients (Node.js/Python) to prevent socket exhaustion.
- **Strict Async/Await:** Never block async threads (`.Result`, `.Wait()`, `time.sleep()`). Blocked threads in consumption plans lead to thread pool starvation and instant execution timeouts.

---

## 1. .NET 8/9/10 Isolated Worker Model

### 1.1 Startup Configuration (`Program.cs`)
```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication(builder =>
    {
        // Custom worker middleware
        builder.UseMiddleware<ExceptionHandlingMiddleware>();
    })
    .ConfigureServices((context, services) =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();

        // Register HTTP Client Factory
        services.AddHttpClient("OrderService", client =>
        {
            client.BaseAddress = new Uri(context.Configuration["OrderService:Url"]!);
            client.Timeout = TimeSpan.FromSeconds(10);
        });

        // Application Services (Scoped per function invocation)
        services.AddScoped<IOrderProcessor, OrderProcessor>();
    })
    .Build();

await host.RunAsync();
```

### 1.2 HTTP Function with Dependency Injection & Validation
```csharp
using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

public class OrderFunctions
{
    private readonly IOrderProcessor _processor;
    private readonly ILogger<OrderFunctions> _logger;

    public OrderFunctions(IOrderProcessor processor, ILogger<OrderFunctions> logger)
    {
        _processor = processor;
        _logger = logger;
    }

    [Function("CreateOrder")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "v1/orders")] HttpRequestData req,
        CancellationToken cancellationToken)
    {
        var orderRequest = await req.ReadFromJsonAsync<CreateOrderRequest>(cancellationToken);
        if (orderRequest is null)
        {
            var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
            await badResponse.WriteStringAsync("Invalid order payload", cancellationToken);
            return badResponse;
        }

        var result = await _processor.ProcessOrderAsync(orderRequest, cancellationToken);

        var response = req.CreateResponse(HttpStatusCode.Created);
        await response.WriteAsJsonAsync(result, cancellationToken);
        return response;
    }
}
```

---

## 2. Node.js v4 Programming Model (TypeScript)

```typescript
// src/functions/orderHandler.ts
import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";

export async function createOrder(
  request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  context.log(`Processing HTTP request for url "${request.url}"`);

  try {
    const body = (await request.json()) as { itemId: string; quantity: number };
    
    if (!body?.itemId || body.quantity <= 0) {
      return { status: 400, jsonBody: { error: "Invalid item or quantity" } };
    }

    return {
      status: 201,
      jsonBody: { orderId: crypto.randomUUID(), status: "Accepted" },
    };
  } catch (err: any) {
    context.error("Failed to process order", err);
    return { status: 500, jsonBody: { error: "Internal processing error" } };
  }
}

// Register function directly in code (no function.json required)
app.http("createOrder", {
  methods: ["POST"],
  authLevel: "function",
  route: "v1/orders",
  handler: createOrder,
});
```

---

## 3. Python v2 Programming Model

```python
# function_app.py
import azure.functions as func
import logging
import json

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="v1/telemetry", methods=["POST"])
@app.cosmos_db_output(
    arg_name="document",
    database_name="AppDb",
    container_name="Telemetry",
    connection="CosmosDbConnectionString"
)
def ingest_telemetry(req: func.HttpRequest, document: func.Out[func.Document]) -> func.HttpResponse:
    logging.info("Processing telemetry ingest request.")
    try:
        req_body = req.get_json()
        device_id = req_body.get("deviceId")
        
        if not device_id:
            return func.HttpResponse("Missing deviceId", status_code=400)
            
        # Write directly to Cosmos DB via output binding
        document.set(func.Document.from_dict(req_body))
        return func.HttpResponse(json.dumps({"status": "Stored"}), status_code=200, mimetype="application/json")
    except Exception as e:
        logging.error(f"Error processing telemetry: {e}")
        return func.HttpResponse("Invalid request payload", status_code=400)
```

---

## 4. Durable Functions Orchestration Patterns

```csharp
// Async HTTP 202 Long-Running Pattern with Durable Functions (.NET Isolated)
[Function(nameof(OrderOrchestrator))]
public static async Task<OrderResult> OrderOrchestrator(
    [OrchestrationTrigger] TaskOrchestrationContext context)
{
    var order = context.GetInput<OrderDto>();

    // 1. Fan-out verification activities
    var inventoryTask = context.CallActivityAsync<bool>(nameof(CheckInventory), order);
    var paymentTask = context.CallActivityAsync<bool>(nameof(PreAuthorizePayment), order);

    await Task.WhenAll(inventoryTask, paymentTask);

    if (!inventoryTask.Result || !paymentTask.Result)
    {
        await context.CallActivityAsync(nameof(CompensateOrder), order);
        return new OrderResult { Success = false };
    }

    // 2. Sequential completion
    return await context.CallActivityAsync<OrderResult>(nameof(FinalizeOrder), order);
}
```

---

## 5. ⚠️ Production Sharp Edges & Solutions

| Anti-Pattern / Issue | Severity | Root Cause | Production Solution |
| :--- | :--- | :--- | :--- |
| **New `HttpClient` per call** | 🔴 Critical | Socket exhaustion under load | Register `services.AddHttpClient()` in `Program.cs` and inject `IHttpClientFactory`. |
| **Blocking async (`.Result`)** | 🔴 Critical | Thread pool starvation | Always use pure `async`/`await` and propagate `CancellationToken`. |
| **Consumption Plan Timeouts** | 🟡 High | Default 5 min timeout limit | Configure `functionTimeout: "00:10:00"` in `host.json` or use Premium / Durable Functions for long tasks. |
| **Cold Starts** | 🟡 High | Dynamic container spin-up | Use Azure Functions **Flex Consumption** or **Premium Plan**, enable Warmup Triggers, and minify bundles. |
| **In-Process Model in .NET 8+** | 🔴 Critical | Deprecated runtime model | Migrate to **Isolated Worker Model** (`Microsoft.Azure.Functions.Worker.Sdk`). |
| **Missing App Insights Sampling** | 🟡 Medium | High telemetry costs & throttling | Tune sampling percentage in `host.json` under `logging.applicationInsights.samplingSettings`. |
