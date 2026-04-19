module.exports = {
  branches: ["main"],
  tagFormat: "rescript-signals-react-v${version}",
  plugins: [
    ["@semantic-release/commit-analyzer", {
      preset: "conventionalcommits",
      releaseRules: [
        { type: "feat", release: "minor" },
        { type: "fix", release: "patch" },
        { type: "perf", release: "patch" },
        { type: "revert", release: "patch" },
        { type: "refactor", release: "patch" },
        { type: "docs", release: false },
        { type: "style", release: false },
        { type: "test", release: false },
        { type: "build", release: false },
        { type: "ci", release: false },
        { type: "chore", release: false },
        { breaking: true, release: "major" },
      ],
    }],
    ["@semantic-release/release-notes-generator", {
      preset: "conventionalcommits",
      presetConfig: {
        types: [
          { type: "feat", section: "Features" },
          { type: "fix", section: "Bug Fixes" },
          { type: "perf", section: "Performance Improvements" },
          { type: "revert", section: "Reverts" },
          { type: "docs", section: "Documentation" },
          { type: "style", section: "Styles" },
          { type: "refactor", section: "Code Refactoring" },
          { type: "test", section: "Tests" },
          { type: "build", section: "Build System" },
          { type: "ci", section: "Continuous Integration" },
        ],
      },
    }],
    ["@semantic-release/changelog", { changelogFile: "CHANGELOG.md" }],
    ["@semantic-release/npm", { npmPublish: true, provenance: true }],
    ["@semantic-release/github"],
    ["@semantic-release/git", {
      assets: ["packages/rescript-signals-react/CHANGELOG.md", "packages/rescript-signals-react/package.json"],
      message: "chore(release): rescript-signals-react ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}",
    }],
  ],
};
