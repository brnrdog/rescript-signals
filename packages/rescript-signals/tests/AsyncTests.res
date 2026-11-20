@@warning("-44")
open Zekr
open Signals

exception Offline(string)

type deferred<'a> = {
  promise: promise<'a>,
  resolve: 'a => unit,
  reject: exn => unit,
}

let deferred: unit => deferred<'a> = %raw(`function () {
  let resolve, reject
  const promise = new Promise((ok, fail) => { resolve = ok; reject = fail })
  return { promise, resolve, reject }
}`)

// Lets every settled promise run its callbacks.
let settle = (): promise<unit> => Promise.make((resolve, _) => setTimeout(() => resolve(), 0)->ignore)

// An async value whose every fetch waits on a promise of its own, kept in
// order; the fetch reads `input` before returning, so it depends on it.
let controlled = (input: Signal.t<string>) => {
  let fetches: array<(string, deferred<string>)> = []
  let value = Async.make(() => {
    let fetch = deferred()
    fetches->Array.push((Signal.get(input), fetch))->ignore
    fetch.promise
  })
  (value, fetches)
}

let resolveNth = (fetches: array<(string, deferred<string>)>, n, value) => {
  let (_, fetch) = fetches->Array.getUnsafe(n)
  fetch.resolve(value)
}

let rejectNth = (fetches: array<(string, deferred<string>)>, n, exn) => {
  let (_, fetch) = fetches->Array.getUnsafe(n)
  fetch.reject(exn)
}

// What a read gives: the value, "not ready", or the failure. A tracked read,
// so inside an effect it subscribes.
let read = (signal: Signal.t<string>): string =>
  switch Signal.get(signal) {
  | value => value
  | exception Async.NotReady => "not ready"
  | exception Offline(reason) => "offline:" ++ reason
  }

// Keeps a reader on `signal`, so it is attached and fetches again as soon as
// a dependency changes; reads through `read`, so a failure does not escape.
let watch = (signal: Signal.t<string>) =>
  Effect.run(() => {
    let _ = read(signal)
    None
  })

let tests = Suite.async(
  "Async Tests",
  [
    Test.async("a read throws NotReady until the first fetch settles", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      let before = read(user)
      resolveNth(fetches, 0, "ada")
      await settle()
      Assert.combineResults([Assert.equal(before, "not ready"), Assert.equal(read(user), "ada")])
    }),
    Test.async("a dependency change fetches again, keeping the value meanwhile", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      let seen = []
      Effect.run(() => {
        seen->Array.push(Signal.get(user))->ignore
        None
      })
      resolveNth(fetches, 0, "ada")
      await settle()
      Signal.set(input, "2")
      let refreshing = (read(user), Async.isPending(() => Signal.get(user)))
      resolveNth(fetches, 1, "grace")
      await settle()
      Assert.combineResults([
        Assert.equal(fetches->Array.map(((input, _)) => input), ["1", "2"]),
        Assert.equal(refreshing, ("ada", true)),
        Assert.isFalse(Async.isPending(() => Signal.get(user))),
        Assert.equal(seen, ["ada", "ada", "grace"]),
      ])
    }),
    Test.async("settling does not run the fetch again", async () => {
      let calls = ref(0)
      let user = Async.make(() => {
        calls := calls.contents + 1
        Promise.resolve("ada")
      })
      watch(user)
      await settle()
      Assert.combineResults([Assert.equal(read(user), "ada"), Assert.equal(calls.contents, 1)])
    }),
    Test.async("only the latest fetch settles it", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      watch(user)
      Signal.set(input, "2")
      resolveNth(fetches, 1, "two")
      await settle()
      resolveNth(fetches, 0, "one")
      await settle()
      Assert.equal(read(user), "two")
    }),
    Test.async("a failed fetch is thrown by reads, and a later fetch recovers", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      watch(user)
      rejectNth(fetches, 0, Offline("down"))
      await settle()
      let failed = read(user)
      Signal.set(input, "2")
      let retrying = read(user)
      resolveNth(fetches, 1, "back")
      await settle()
      Assert.combineResults([
        Assert.equal(failed, "offline:down"),
        Assert.equal(retrying, "not ready"),
        Assert.equal(read(user), "back"),
      ])
    }),
    Test.async("a fetch that throws before returning a promise is a failure", async () => {
      let user = Async.make(() => throw(Offline("sync")))
      Assert.equal(read(user), "offline:sync")
    }),
    Test.async("a computed reading it holds NotReady, then recomputes with the value", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      let runs = ref(0)
      let greeting = Computed.make(() => {
        runs := runs.contents + 1
        "hello " ++ Signal.get(user)
      })
      let seen = []
      Effect.run(() => {
        seen->Array.push(read(greeting))->ignore
        None
      })
      let pendingBefore = Async.isPending(() => Signal.get(greeting))
      resolveNth(fetches, 0, "ada")
      await settle()
      Assert.combineResults([
        Assert.isTrue(pendingBefore),
        Assert.equal(seen, ["not ready", "hello ada"]),
        Assert.equal(runs.contents, 2),
      ])
    }),
    Test.async("an effect that reads a value not there yet waits for it", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      let seen = []
      Effect.run(() => {
        seen->Array.push(Signal.get(user))->ignore
        None
      })
      let whileWaiting = Array.copy(seen)
      resolveNth(fetches, 0, "ada")
      await settle()
      Assert.combineResults([Assert.equal(whileWaiting, []), Assert.equal(seen, ["ada"])])
    }),
    Test.async("isPending reports a refetch through a computed", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      let shouted = Computed.make(() => Signal.get(user) ++ "!")
      let pending = []
      Effect.run(() => {
        pending->Array.push(Async.isPending(() => Signal.get(shouted)))->ignore
        None
      })
      resolveNth(fetches, 0, "ada")
      await settle()
      Signal.set(input, "2")
      resolveNth(fetches, 1, "grace")
      await settle()
      Assert.combineResults([
        Assert.equal(pending->Array.at(-1), Some(false)),
        Assert.isTrue(pending->Array.includes(true)),
        Assert.equal(read(shouted), "grace!"),
        // Not pending, loaded, pending again on the refetch, loaded.
        Assert.equal(pending, [true, false, true, false]),
      ])
    }),
    Test.async("isPending sees a refetch through a computed already up to date", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      let shouted = Computed.make(() => Signal.get(user) ++ "!")
      watch(shouted)
      resolveNth(fetches, 0, "ada")
      await settle()
      Signal.set(input, "2")
      // The watcher has already brought `shouted` up to date, so asking does
      // not recompute it: only what its last run recorded can tell.
      let cached = Async.isPending(() => Signal.get(shouted))
      resolveNth(fetches, 1, "grace")
      await settle()
      Assert.combineResults([
        Assert.isTrue(cached),
        Assert.isFalse(Async.isPending(() => Signal.get(shouted))),
      ])
    }),
    Test.async("isPending throws a failure other than NotReady", async () => {
      let failing = Computed.make(() => throw(Offline("x")))
      let threw = switch Async.isPending(() => Signal.get(failing)) {
      | _ => false
      | exception Offline(_) => true
      }
      Assert.isTrue(threw)
    }),
    Test.async("an unread async value fetches again only when read", async () => {
      let input = Signal.make("1")
      let (user, fetches) = controlled(input)
      resolveNth(fetches, 0, "ada")
      await settle()
      Signal.set(input, "2")
      let fetchedBeforeRead = Array.length(fetches)
      let whileFetching = read(user)
      Assert.combineResults([
        Assert.equal(fetchedBeforeRead, 1),
        Assert.equal(Array.length(fetches), 2),
        Assert.equal(whileFetching, "ada"),
      ])
    }),
  ],
)

Runner.runAsyncSuites([tests])->ignore
