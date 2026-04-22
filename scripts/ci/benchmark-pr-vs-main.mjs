import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

function envOrDefault(name, fallback) {
  const value = process.env[name];
  return value && value.length > 0 ? value : fallback;
}

function toCsvValue(value) {
  if (typeof value === "number") return value.toString();
  if (value.includes(",") || value.includes("\"") || value.includes("\n")) {
    return `"${value.replaceAll("\"", "\"\"")}"`;
  }
  return value;
}

function percentDelta(current, baseline) {
  if (baseline === 0) return Number.NaN;
  return ((current - baseline) / baseline) * 100;
}

function toMarkdownComment(mainLabel, currentLabel, results) {
  const byFramework = new Map();
  for (const row of results) {
    const list = byFramework.get(row.framework) ?? [];
    list.push(row);
    byFramework.set(row.framework, list);
  }

  const mainRows = byFramework.get(mainLabel) ?? [];
  const currentRows = byFramework.get(currentLabel) ?? [];
  const testNames = Array.from(
    new Set(mainRows.map((r) => r.test).concat(currentRows.map((r) => r.test))),
  ).sort();

  const mainByTest = new Map(mainRows.map((r) => [r.test, r.time]));
  const currentByTest = new Map(currentRows.map((r) => [r.test, r.time]));

  const totalMain = mainRows.reduce((sum, row) => sum + row.time, 0);
  const totalCurrent = currentRows.reduce((sum, row) => sum + row.time, 0);
  const totalDiff = totalCurrent - totalMain;
  const totalDiffPct = percentDelta(totalCurrent, totalMain);

  const lines = [];
  lines.push("### ReScript Signals benchmark: PR vs main");
  lines.push("");
  lines.push("Compared implementations:");
  lines.push(`- ${mainLabel}`);
  lines.push(`- ${currentLabel}`);
  lines.push("");
  lines.push("Overall:");
  lines.push("");
  lines.push("| Version | Total ms | Avg ms/test |");
  lines.push("| --- | ---: | ---: |");
  lines.push(
    `| ${mainLabel} | ${totalMain.toFixed(2)} | ${(totalMain / testNames.length).toFixed(2)} |`,
  );
  lines.push(
    `| ${currentLabel} | ${totalCurrent.toFixed(2)} | ${(totalCurrent / testNames.length).toFixed(2)} |`,
  );
  lines.push(
    `| Delta (${currentLabel} - ${mainLabel}) | ${totalDiff.toFixed(2)} | ${totalDiffPct.toFixed(2)}% |`,
  );
  lines.push("");
  lines.push("Per-test delta (lower is better):");
  lines.push("");
  lines.push("| Test | Main ms | PR ms | Diff ms | Diff % |");
  lines.push("| --- | ---: | ---: | ---: | ---: |");
  for (const test of testNames) {
    const mainTime = mainByTest.get(test) ?? Number.NaN;
    const currentTime = currentByTest.get(test) ?? Number.NaN;
    const diffMs = currentTime - mainTime;
    const diffPct = percentDelta(currentTime, mainTime);
    lines.push(
      `| ${test} | ${mainTime.toFixed(2)} | ${currentTime.toFixed(2)} | ${diffMs.toFixed(2)} | ${diffPct.toFixed(2)}% |`,
    );
  }
  lines.push("");
  lines.push(
    "_Note: single-machine run in CI. Numbers can vary with runner load and Node/V8 version._",
  );
  lines.push("");

  return lines.join("\n");
}

function createReScriptFramework(name, modules) {
  let disposers = [];

  return {
    name,
    signal: (initialValue) => {
      const s = modules.Signal.make(initialValue);
      return {
        read: () => modules.Signal.get(s),
        write: (v) => modules.Signal.set(s, v),
      };
    },
    computed: (fn) => {
      const c = modules.Computed.make(fn);
      return {
        read: () => modules.Signal.get(c),
      };
    },
    effect: (fn) => {
      const disposer = modules.Effect.runWithDisposer(() => {
        fn();
        return undefined;
      });
      disposers.push(disposer);
    },
    withBatch: (fn) => {
      modules.Signal.batch(fn);
    },
    withBuild: (fn) => fn(),
    cleanup: () => {
      for (const disposer of disposers) {
        disposer.dispose();
      }
      disposers = [];
    },
  };
}

function resolveSignalsDir(baseDir, label) {
  const candidates = [
    baseDir,
    resolve(baseDir, "src"),
    resolve(baseDir, "src/signals"),
    resolve(baseDir, "lib/bs/src/signals"),
  ];

  for (const candidate of candidates) {
    const bundledEntryFile = resolve(candidate, "Signals.res.mjs");
    if (existsSync(bundledEntryFile)) {
      return {
        type: "entry",
        file: bundledEntryFile,
      };
    }

    const signalFile = resolve(candidate, "Signal.res.mjs");
    const computedFile = resolve(candidate, "Computed.res.mjs");
    const effectFile = resolve(candidate, "Effect.res.mjs");
    if (existsSync(signalFile) && existsSync(computedFile) && existsSync(effectFile)) {
      return {
        type: "split",
        dir: candidate,
      };
    }

    const prefixedSignalFile = resolve(candidate, "Signals__Signal.res.mjs");
    const prefixedComputedFile = resolve(candidate, "Signals__Computed.res.mjs");
    const prefixedEffectFile = resolve(candidate, "Signals__Effect.res.mjs");
    if (
      existsSync(prefixedSignalFile) &&
      existsSync(prefixedComputedFile) &&
      existsSync(prefixedEffectFile)
    ) {
      return {
        type: "split",
        dir: candidate,
        prefixed: true,
      };
    }
  }

  throw new Error(
    `Could not resolve ReScript module directory for ${label}. Tried: ${candidates.join(", ")}`,
  );
}

async function importSignalModules(signalsDir, label) {
  const resolvedSignalsDir = resolveSignalsDir(signalsDir, label);

  if (resolvedSignalsDir.type === "entry") {
    const modules = await import(pathToFileURL(resolvedSignalsDir.file).href);
    return {
      Signal: modules.Signal,
      Computed: modules.Computed,
      Effect: modules.Effect,
    };
  }

  const dir = resolvedSignalsDir.dir;
  const isPrefixed = resolvedSignalsDir.prefixed;
  const prefix = isPrefixed ? "Signals__" : "";

  return {
    Signal: await import(pathToFileURL(resolve(dir, `${prefix}Signal.res.mjs`)).href),
    Computed: await import(pathToFileURL(resolve(dir, `${prefix}Computed.res.mjs`)).href),
    Effect: await import(pathToFileURL(resolve(dir, `${prefix}Effect.res.mjs`)).href),
  };
}

async function main() {
  const repoRoot = process.cwd();
  const benchCoreDistDir = envOrDefault(
    "BENCH_CORE_DIST_DIR",
    resolve(repoRoot, ".tmp/js-reactivity-benchmark/packages/core/dist"),
  );
  const currentSignalsDir = envOrDefault(
    "CURRENT_SIGNALS_DIR",
    resolve(repoRoot, "packages/rescript-signals"),
  );
  const mainSignalsDir = envOrDefault(
    "MAIN_SIGNALS_DIR",
    resolve(repoRoot, "main-baseline/packages/rescript-signals"),
  );
  const outDir = envOrDefault(
    "BENCH_OUT_DIR",
    resolve(repoRoot, "benchmark-results/ci/pr-vs-main"),
  );

  const benchApi = await import(pathToFileURL(resolve(benchCoreDistDir, "index.js")).href);
  const { runTests } = benchApi;

  const mainModules = await importSignalModules(mainSignalsDir, "main");
  const currentModules = await importSignalModules(currentSignalsDir, "PR");

  const mainLabel = "ReScript Signals (main)";
  const currentLabel = "ReScript Signals (PR)";

  const frameworks = [
    { framework: createReScriptFramework(mainLabel, mainModules), testPullCounts: false },
    { framework: createReScriptFramework(currentLabel, currentModules), testPullCounts: false },
  ];

  const results = [];
  console.assert = () => {};
  console.log(`Running benchmark: ${mainLabel} vs ${currentLabel}`);
  await runTests(frameworks, (result) => {
    results.push(result);
  });

  mkdirSync(outDir, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const csvPath = resolve(outDir, `results-${timestamp}.csv`);
  const jsonPath = resolve(outDir, `results-${timestamp}.json`);
  const commentPath = resolve(outDir, `pr-comment-${timestamp}.md`);
  const latestCsvPath = resolve(outDir, "results-latest.csv");
  const latestJsonPath = resolve(outDir, "results-latest.json");
  const latestCommentPath = resolve(outDir, "pr-comment-latest.md");

  const csvLines = [
    "framework,test,time_ms",
    ...results.map((r) =>
      [r.framework, r.test, r.time.toFixed(4)].map(toCsvValue).join(","),
    ),
  ];

  const payload = {
    timestamp: new Date().toISOString(),
    benchmark: "milomg/js-reactivity-benchmark",
    compared: [mainLabel, currentLabel],
    results,
  };

  const comment = toMarkdownComment(mainLabel, currentLabel, results);

  writeFileSync(csvPath, csvLines.join("\n"));
  writeFileSync(jsonPath, JSON.stringify(payload, null, 2));
  writeFileSync(commentPath, comment);

  writeFileSync(latestCsvPath, csvLines.join("\n"));
  writeFileSync(latestJsonPath, JSON.stringify(payload, null, 2));
  writeFileSync(latestCommentPath, comment);

  console.log(`Saved CSV: ${csvPath}`);
  console.log(`Saved JSON: ${jsonPath}`);
  console.log(`Saved PR comment: ${commentPath}`);
  console.log(`Saved latest PR comment: ${latestCommentPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
