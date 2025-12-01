module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // New feature
        'fix',      // Bug fix
        'docs',     // Documentation changes
        'style',    // Code style changes (formatting, etc)
        'refactor', // Code refactoring
        'perf',     // Performance improvements
        'test',     // Adding or updating tests
        'build',    // Build system or external dependencies
        'ci',       // CI configuration changes
        'chore',    // Other changes that don't modify src or test files
        'revert',   // Revert a previous commit
      ],
    ],
    'subject-case': [0], // Disable subject case enforcement
    'header-max-length': [2, 'always', 50], // 50 character limit for subject line
    'body-max-line-length': [2, 'always', 72], // 72 character limit for body lines
    'footer-max-line-length': [2, 'always', 72], // 72 character limit for footer lines
  },
};
