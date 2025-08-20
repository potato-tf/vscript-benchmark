# VScript Benchmark Script

Simple VScript library for performance debugging using the in-game performance counter.  

Drop the `benchmark.nut` file into `tf/scripts/vscripts/`, include it in your file, and start benchmarking.

### Basic setup

```js
// Example benchmark file:

IncludeScript( "benchmark" )

function Benchmark::MyFunction1() {

    // ...
}

function Benchmark::MyFunction2() {

    // ...
}

function Benchmark::MyFunction3() {

    // ...
}

// start benchmarking loop
Benchmark.Start()

// stop the loop after 30s
Benchmark.Stop( 30 )
```

### Advanced setup

```js

function Benchmark::MyFunction1() {

    // ...
}

// this will also work if you want
function MyFunction2() {

    // ...
}
Benchmark.Add( MyFunction2, 3 ) // 3s delay

function MyFunction3() {

    // ...
}

// run all registered functions once
Benchmark.StartOnce()

// One-off single function call with an optional delay
Benchmark.RunOnce( MyFunction3, 10 ) // 10s delay
```

### Notes

- Any functions following the `Benchmark::MyFunc` or `Benchmark.MyFunc <- function()` format will be registered in the order they are defined
    - use `Benchmark.Add()` to manually register functions
    - All functions prefixed with an underscore are considered "internal" and will need to be manually registered
- Intended for solo testing/listen servers, dedicated works but not recommended due to heavy reliance on `con_filter...` commands.
    - Dedicated servers must do one of the following:
        - add "vscript_perf_warning_spew_ms" to their convar allowlist
        - set sv_allow_point_servercommand to "always"
        - manually set the convar to 0.0 and ignore the perf warnings for internal library functions
- stop and kill the entire benchmark system with `ent_fire __benchmark Kill`, or trigger a round restart.
    - If your benchmark code involves restarting the round in a game event, you may need to add `IncludeScript( "benchmark" )` in that game event.
