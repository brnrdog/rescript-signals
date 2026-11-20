open Zekr

// Run all test suites
Runner.runSuites([
  SignalTests.tests,
  ComputedTests.tests,
  FailureTests.tests,
  EffectTests.tests,
  LifecycleTests.tests,
  DebugTests.tests,
  PropertyTests.tests,
])
