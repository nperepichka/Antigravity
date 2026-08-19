---
name: javascript-pro
description: Master modern JavaScript (ES2024+), Node.js, Bun, and browser runtime engineering. Covers Event Loop mechanics (microtasks vs macrotasks), AbortController lifecycles, structuredClone, Web Streams API, memory leak prevention, and JSDoc type safety. Use when writing, debugging, or optimizing JavaScript applications.
---

# Modern JavaScript & Runtime Engineering Guide

Comprehensive, production-grade engineering guide for modern JavaScript (ES2024+), V8 engine optimization, asynchronous lifecycles, and high-throughput Node.js/Bun application design.

---

## Core JavaScript Directives

- **Clean Asynchrony with AbortController:** Always accept an `AbortSignal` for cancellable asynchronous operations (HTTP requests, timers, stream consumers).
- **Deep Copying:** Use native `structuredClone()` instead of fragile JSON hacks (`JSON.parse(JSON.stringify(x))`), which drop Dates, Maps, Sets, and binary buffers.
- **Microtask Discipline:** Understand that `Promise.then` and `queueMicrotask` execute before the next tick of the Macrotask queue (`setTimeout`, `setImmediate`, I/O). Starving the microtask queue freezes I/O polling.
- **Error Causality:** Always preserve error lineage using `new Error("Context", { cause: originalError })`.

---

## 1. Event Loop & Microtask Queue Mechanics

```javascript
/**
 * Execution Order Demonstration:
 * 1. Synchronous code
 * 2. process.nextTick / microtasks (Promises, queueMicrotask)
 * 3. Macrotasks (setTimeout, setImmediate, I/O callbacks)
 */
export async function runMicrotaskPipeline() {
  console.log("1. Sync start");

  setTimeout(() => {
    console.log("5. Macrotask (setTimeout)");
  }, 0);

  queueMicrotask(() => {
    console.log("3. Microtask queue");
  });

  await Promise.resolve();
  console.log("4. Microtask (after await)");

  console.log("2. Sync end");
}
```

---

## 2. Robust Asynchronous Lifecycle & Cancellation

```javascript
/**
 * Executes a resilient fetch with automatic timeout and cancellation support.
 * @param {string} url
 * @param {object} [options]
 * @param {number} [options.timeoutMs=5000]
 * @param {AbortSignal} [options.signal]
 * @returns {Promise<any>}
 */
export async function fetchWithTimeout(url, options = {}) {
  const { timeoutMs = 5000, signal: externalSignal, ...fetchOptions } = options;

  // Combine external cancellation with a deterministic timeout
  const timeoutSignal = AbortSignal.timeout(timeoutMs);
  const combinedSignal = externalSignal 
    ? AbortSignal.any([externalSignal, timeoutSignal])
    : timeoutSignal;

  try {
    const response = await fetch(url, { ...fetchOptions, signal: combinedSignal });
    if (!response.ok) {
      throw new Error(`HTTP Error: ${response.status} ${response.statusText}`);
    }
    return await response.json();
  } catch (err) {
    if (err.name === "AbortError" || err.name === "TimeoutError") {
      throw new Error(`Request to ${url} aborted or timed out after ${timeoutMs}ms`, { cause: err });
    }
    throw new Error(`Failed to fetch ${url}`, { cause: err });
  }
}
```

---

## 3. High-Throughput Web Streams API

```javascript
import { pipeline } from 'node:stream/promises';
import { createReadStream, createWriteStream } from 'node:fs';
import { Transform } from 'node:stream';

/**
 * Transforms JSON Lines stream with minimal memory footprint.
 * @param {string} inputPath
 * @param {string} outputPath
 */
export async function processLargeJsonlStream(inputPath, outputPath) {
  let lineCount = 0;

  const lineTransformer = new Transform({
    objectMode: true,
    transform(chunk, encoding, callback) {
      try {
        const line = chunk.toString().trim();
        if (line) {
          const parsed = JSON.parse(line);
          parsed.processedAt = new Date().toISOString();
          parsed.index = ++lineCount;
          this.push(JSON.stringify(parsed) + '\n');
        }
        callback();
      } catch (err) {
        callback(err);
      }
    }
  });

  // Automatically manages backpressure and resource cleanup
  await pipeline(
    createReadStream(inputPath, { encoding: 'utf-8' }),
    lineTransformer,
    createWriteStream(outputPath)
  );
}
```

---

## 4. Memory Leak Prevention & Weak References

```javascript
// Cache that automatically allows garbage collection when DOM/object keys are removed
const metadataCache = new WeakMap();

/**
 * Attaches metadata to an object without preventing its garbage collection.
 * @param {object} targetObject
 * @param {Record<string, any>} metadata
 */
export function setTransientMetadata(targetObject, metadata) {
  metadataCache.set(targetObject, {
    ...metadata,
    cachedAt: performance.now(),
  });
}

export function getTransientMetadata(targetObject) {
  return metadataCache.get(targetObject);
}
```

---

## 5. ⚠️ Production Sharp Edges & Solutions

| Anti-Pattern / Hazard | Severity | Root Cause | Production Solution |
| :--- | :--- | :--- | :--- |
| **Unhandled Promise Rejections** | 🔴 Critical | Missing `catch` blocks in detached async calls | Always handle errors at async boundaries or wrap with `Promise.allSettled()`. |
| **`JSON.parse(JSON.stringify(x))`** | 🟡 High | Loses `Date`, `Map`, `Set`, `BigInt`, `RegExp` | Use native `structuredClone(x)` for deep cloning. |
| **Memory Leak in Event Listeners** | 🟡 High | Forgetting to `removeEventListener` | Pass `{ signal: abortController.signal }` in `addEventListener` for automatic cleanup. |
| **Microtask Starvation** | 🔴 Critical | Infinite recursive `queueMicrotask` or unresolved promises | Yield to macrotask queue via `await new Promise(r => setTimeout(r, 0))` in long loops. |
| **Async Callback Hell** | 🟡 Medium | Nesting legacy Node.js errback callbacks | Use `node:util` `promisify` or native `fs/promises` APIs. |
