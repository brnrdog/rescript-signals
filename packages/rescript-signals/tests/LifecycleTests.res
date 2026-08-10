@@warning("-44")
open Zekr
open Signals

// Number of live subscribers attached to a signal. A computed that has detached
// from its sources leaves no link behind, so this is what the leak tests assert on.
let subscriberCount = (signal: Signal.t<'a>): int => {
  let count = ref(0)
  let link = ref(signal.subs.first)
  while link.contents !== None {
    switch link.contents {
    | Some(l) =>
      count := count.contents + 1
      link := l.nextSub
    | None => ()
    }
  }
  count.contents
}

let tests = Suite.make(
  "Computed Lifecycle Tests",
  [
    Test.make("computed does not attach to its source until it has a subscriber", () => {
      let source = Signal.make(1)
      let _doubled = Computed.make(() => Signal.get(source) * 2)

      Assert.equal(
        subscriberCount(source),
        0,
        ~message="An unsubscribed computed should not sit in the source's subscriber list",
      )
    }),
    Test.make("computed attaches while subscribed and detaches afterwards", () => {
      let source = Signal.make(1)
      let doubled = Computed.make(() => Signal.get(source) * 2)

      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(doubled)
        None
      })

      let whileSubscribed = Assert.equal(
        subscriberCount(source),
        1,
        ~message="A subscribed computed should be attached to its source",
      )

      disposer.dispose()

      let afterDisposal = Assert.equal(
        subscriberCount(source),
        0,
        ~message="A computed should detach once its last subscriber goes away",
      )

      Assert.combineResults([whileSubscribed, afterDisposal])
    }),
    Test.make("discarded computeds do not accumulate on the source", () => {
      let source = Signal.make(0)

      for i in 1 to 100 {
        let _ = Computed.make(() => Signal.get(source) + i)
      }

      Assert.equal(
        subscriberCount(source),
        0,
        ~message="Creating and dropping computeds should leave the source untouched",
      )
    }),
    Test.make("repeated subscribe/unsubscribe cycles do not accumulate", () => {
      let source = Signal.make(0)

      for _ in 1 to 100 {
        let derived = Computed.make(() => Signal.get(source) * 2)
        let disposer = Effect.runWithDisposer(() => {
          let _ = Signal.get(derived)
          None
        })
        disposer.dispose()
      }

      Assert.equal(
        subscriberCount(source),
        0,
        ~message="Full subscribe/unsubscribe cycles should leave no links behind",
      )
    }),
    Test.make("chained computeds detach transitively", () => {
      let source = Signal.make(1)
      let doubled = Computed.make(() => Signal.get(source) * 2)
      let quadrupled = Computed.make(() => Signal.get(doubled) * 2)

      let disposer = Effect.runWithDisposer(() => {
        let _ = Signal.get(quadrupled)
        None
      })

      let whileSubscribed = Assert.equal(
        subscriberCount(source),
        1,
        ~message="The whole chain should be attached while the tail is subscribed",
      )

      disposer.dispose()

      let sourceDetached = Assert.equal(
        subscriberCount(source),
        0,
        ~message="Detaching should propagate up the chain to the root signal",
      )
      let middleDetached = Assert.equal(
        subscriberCount(doubled),
        0,
        ~message="The intermediate computed should have no subscribers left",
      )

      Assert.combineResults([whileSubscribed, sourceDetached, middleDetached])
    }),
    Test.make("detached computed still reads the latest value", () => {
      let a = Signal.make(1)
      let b = Signal.make(10)
      let sum = Computed.make(() => Signal.get(a) + Signal.get(b))
      let doubled = Computed.make(() => Signal.get(sum) * 2)

      let initial = Assert.equal(Signal.get(doubled), 22, ~message="Initial value should be 22")

      Signal.set(a, 5)
      let afterFirst = Assert.equal(
        Signal.get(doubled),
        30,
        ~message="A detached computed should still see writes to its source",
      )

      Signal.set(b, 100)
      let afterSecond = Assert.equal(
        Signal.get(doubled),
        210,
        ~message="A detached chain should recompute through every level",
      )

      Assert.combineResults([initial, afterFirst, afterSecond])
    }),
    Test.make("detached computed is not recomputed by unrelated writes", () => {
      let source = Signal.make(1)
      let unrelated = Signal.make(0)
      let computeCount = ref(0)
      let derived = Computed.make(() => {
        computeCount := computeCount.contents + 1
        Signal.get(source)
      })

      let _ = Signal.get(derived)
      let baseline = computeCount.contents

      Signal.set(unrelated, 1)
      let _ = Signal.get(derived)
      let _ = Signal.get(derived)

      Assert.equal(
        computeCount.contents,
        baseline,
        ~message="Writes to an unrelated signal should not force a recompute",
      )
    }),
    Test.make("subscribing after detached writes sees the latest value", () => {
      let source = Signal.make(1)
      let doubled = Computed.make(() => Signal.get(source) * 2)

      // Written while nothing is subscribed, so no notification is delivered.
      Signal.set(source, 21)

      let observed = ref(0)
      let disposer = Effect.runWithDisposer(() => {
        observed := Signal.get(doubled)
        None
      })

      let onAttach = Assert.equal(
        observed.contents,
        42,
        ~message="Re-attaching should reconcile the value missed while detached",
      )

      Signal.set(source, 3)
      let afterAttach = Assert.equal(
        observed.contents,
        6,
        ~message="Updates should propagate normally once re-attached",
      )

      disposer.dispose()
      Signal.set(source, 5)
      let afterDetach = Assert.equal(
        Signal.get(doubled),
        10,
        ~message="Reads should stay correct after detaching again",
      )

      Assert.combineResults([onAttach, afterAttach, afterDetach])
    }),
    Test.make("disposed computed rebuilds itself on the next read", () => {
      let source = Signal.make(1)
      let doubled = Computed.make(() => Signal.get(source) * 10)

      let before = Assert.equal(Signal.get(doubled), 10, ~message="Initial value should be 10")

      Computed.dispose(doubled)
      Signal.set(source, 5)

      let after = Assert.equal(
        Signal.get(doubled),
        50,
        ~message="A disposed computed should recompute rather than report a stale value",
      )

      Assert.combineResults([before, after])
    }),
    Test.make("writes stay correct with many live subscribers", () => {
      let source = Signal.make(1)
      let derived = Computed.make(() => Signal.get(source) * 2)
      let observed = ref([])
      let disposers = []

      for _ in 1 to 5 {
        let disposer = Effect.runWithDisposer(() => {
          observed := observed.contents->Array.concat([Signal.get(derived)])
          None
        })
        disposers->Array.push(disposer)
      }

      Signal.set(source, 3)

      let attached = Assert.equal(
        subscriberCount(source),
        1,
        ~message="Five subscribers on one computed still means one link to the source",
      )
      let value = Assert.equal(
        Signal.get(derived),
        6,
        ~message="Computed should reflect the latest write",
      )

      disposers->Array.forEach(d => d.dispose())

      let detached = Assert.equal(
        subscriberCount(source),
        0,
        ~message="Source should be free once every subscriber is gone",
      )

      Assert.combineResults([attached, value, detached])
    }),
  ],
)
