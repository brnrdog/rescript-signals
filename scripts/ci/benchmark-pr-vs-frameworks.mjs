import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const SELECTED_FRAMEWORKS = [
  "Alien Signals",
  "Preact Signals",
  "SolidJS",
  "Svelte v5",
  "Vue",
];

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

function summarize(results) {
  const byFramework = new Map();
  const tests = new Set();

  for (const row of results) {
    tests.add(row.test);
    const list = byFramework.get(row.framework) ?? [];
    list.push(row);
    byFramework.set(row.framework, list);
  }

  const ranking = [...byFramework.entries()]
    .map(([framework, rows]) => {
      const total = rows.reduce((sum, r) => sum + r.time, 0);
      const avg = total / rows.length;
      return { framework, rows, total, avg };
    })
    .sort((a, b) => a.total - b.total);

  return { ranking, tests: [...tests].sort() };
}

function toMarkdownComment(frameworkNames, results) {
  const { ranking, tests } = summarize(results);

  const lines = [];
  lines.push("### Reactivity benchmark: PR vs top frameworks");
  lines.push("");
  lines.push("Compared implementations:");
  for (const name of frameworkNames) {
    lines.push(`- ${name}`);
  }
  lines.push("");
  lines.push("Overall ranking (lower total ms is better):");
  lines.push("");
  lines.push("| Rank | Framework | Total ms | Avg ms/test |");
  lines.push("| --- | --- | ---: | ---: |");
  ranking.forEach((entry, i) => {
    lines.push(
      `| ${i + 1} | ${entry.framework} | ${entry.total.toFixed(2)} | ${entry.avg.toFixed(2)} |`,
    );
  });
  lines.push("");
  lines.push("Per-test runtime (ms):");
  lines.push("");
  lines.push(`| Framework | ${tests.join(" | ")} |`);
  lines.push(`| --- | ${tests.map(() => "---:").join(" | ")} |`);
  for (const entry of ranking) {
    const byTest = new Map(entry.rows.map((r) => [r.test, r.time]));
    const values = tests.map((test) => (byTest.get(test) ?? Number.NaN).toFixed(2));
    lines.push(`| ${entry.framework} | ${values.join(" | ")} |`);
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

function resolveSignalsDir(baseDir) {
  const candidates = [
    baseDir,
    resolve(baseDir, "src/signals"),
    resolve(baseDir, "lib/bs/src/signals"),
  ];

  for (const candidate of candidates) {
    const signalFile = resolve(candidate, "Signal.res.mjs");
    const computedFile = resolve(candidate, "Computed.res.mjs");
    const effectFile = resolve(candidate, "Effect.res.mjs");
    if (existsSync(signalFile) && existsSync(computedFile) && existsSync(effectFile)) {
      return candidate;
    }
  }

  throw new Error(`Could not resolve ReScript modules. Tried: ${candidates.join(", ")}`);
}

async function importSignalModules(baseDir) {
  const signalsDir = resolveSignalsDir(baseDir);
  return {
    Signal: await import(pathToFileURL(resolve(signalsDir, "Signal.res.mjs")).href),
    Computed: await import(pathToFileURL(resolve(signalsDir, "Computed.res.mjs")).href),
    Effect: await import(pathToFileURL(resolve(signalsDir, "Effect.res.mjs")).href),
  };
}

function pickFrameworks(allFrameworks, rescriptFramework) {
  const map = new Map(allFrameworks.map((entry) => [entry.framework.name, entry]));
  const chosen = [];

  for (const name of SELECTED_FRAMEWORKS) {
    const found = map.get(name);
    if (!found) {
      throw new Error(`Framework not found in benchmark suite: ${name}`);
    }
    chosen.push(found);
  }

  chosen.push({
    framework: rescriptFramework,
    testPullCounts: false,
  });

  return chosen;
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
  const outDir = envOrDefault(
    "BENCH_OUT_DIR",
    resolve(repoRoot, "benchmark-results/ci/pr-vs-frameworks"),
  );

  const benchApi = await import(pathToFileURL(resolve(benchCoreDistDir, "index.js")).href);
  const { runTests, allFrameworks } = benchApi;

  const currentModules = await importSignalModules(currentSignalsDir);
  const rescriptFramework = createReScriptFramework("ReScript Signals (PR)", currentModules);
  const frameworks = pickFrameworks(allFrameworks, rescriptFramework);
  const frameworkNames = frameworks.map((entry) => entry.framework.name);

  const results = [];
  console.assert = () => {};
  console.log(`Running selected frameworks: ${frameworkNames.join(", ")}`);
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
    frameworks: frameworkNames,
    results,
  };

  const comment = toMarkdownComment(frameworkNames, results);

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
