// Simple benchmark for rescript-signals
import { Signal, Computed, Effect } from './src/Signals.res.mjs';

function benchmark(name, fn, iterations = 10000) {
  // Warmup
  for (let i = 0; i < 10; i++) fn();

  const start = performance.now();
  for (let i = 0; i < iterations; i++) {
    fn();
  }
  const end = performance.now();
  const total = end - start;
  const perOp = total / iterations;
  console.log(`${name}: ${total.toFixed(2)}ms total, ${perOp.toFixed(4)}ms/op`);
  return total;
}

console.log('\n=== ReScript Signals Benchmark ===\n');

// Test 1: Create Signals
console.log('--- Signal Creation ---');
benchmark('Create 10000 signals', () => {
  const signals = [];
  for (let i = 0; i < 10000; i++) {
    signals.push(Signal.make(i));
  }
}, 100);

// Test 2: Create Computeds
console.log('\n--- Computed Creation ---');
benchmark('Create 10000 computeds (simple)', () => {
  const signals = [];
  const computeds = [];
  for (let i = 0; i < 10000; i++) {
    const s = Signal.make(i);
    signals.push(s);
    computeds.push(Computed.make(() => Signal.get(s) * 2));
  }
}, 100);

// Test 3: Deep computed chain
console.log('\n--- Deep Computed Chain ---');
benchmark('Create chain of 100 computeds', () => {
  const source = Signal.make(1);
  let prev = source;
  for (let i = 0; i < 100; i++) {
    const current = prev;
    prev = Computed.make(() => Signal.get(current) + 1);
  }
  // Read the final value to ensure chain is evaluated
  Signal.get(prev);
}, 100);

// Test 4: Signal updates
console.log('\n--- Signal Updates ---');
{
  const source = Signal.make(0);
  const computeds = [];
  for (let i = 0; i < 100; i++) {
    computeds.push(Computed.make(() => Signal.get(source) * 2));
  }

  benchmark('Update signal with 100 computed observers', () => {
    Signal.set(source, Signal.get(source) + 1);
    // Read all computeds to force evaluation
    for (const c of computeds) {
      Signal.get(c);
    }
  }, 10000);
}

// Test 5: Wide dependency tree
console.log('\n--- Wide Dependency Tree ---');
{
  const sources = [];
  for (let i = 0; i < 100; i++) {
    sources.push(Signal.make(i));
  }
  const computed = Computed.make(() => {
    let sum = 0;
    for (const s of sources) {
      sum += Signal.get(s);
    }
    return sum;
  });

  benchmark('Update 1 of 100 source signals', () => {
    Signal.set(sources[0], Signal.get(sources[0]) + 1);
    Signal.get(computed);
  }, 10000);
}

// Test 6: Batched updates
console.log('\n--- Batched Updates ---');
{
  const signals = [];
  for (let i = 0; i < 100; i++) {
    signals.push(Signal.make(i));
  }
  const computed = Computed.make(() => {
    let sum = 0;
    for (const s of signals) {
      sum += Signal.get(s);
    }
    return sum;
  });

  benchmark('Batch update 100 signals', () => {
    Signal.batch(() => {
      for (let i = 0; i < 100; i++) {
        Signal.set(signals[i], Signal.get(signals[i]) + 1);
      }
    });
    Signal.get(computed);
  }, 10000);
}

// Test 7: Effect with updates
console.log('\n--- Effects ---');
{
  let effectCount = 0;
  const source = Signal.make(0);
  const effect = Effect.run(() => {
    Signal.get(source);
    effectCount++;
    return undefined;
  });

  benchmark('Signal update triggering effect', () => {
    Signal.set(source, Signal.get(source) + 1);
  }, 10000);

  effect.dispose();
}

console.log('\n=== Benchmark Complete ===\n');
