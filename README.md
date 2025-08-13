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
EntFire( "__benchmark", "CallScriptFunction", "_Start" )

// stop the loop after 15s
EntFire( "__benchmark", "CallScriptFunction", "_Stop", 15 )
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
Benchmark._Add( MyFunction2, 3 ) // 3s delay

function MyFunction3() {

    // ...
}
// One-off single function call with an optional delay
Benchmark._Run( MyFunction3, 10 ) // 10s delay

// run all registered functions
EntFire( "__benchmark", "CallScriptFunction", "_Start" )
// stop the loop after 30s
EntFire( "__benchmark", "CallScriptFunction", "_Stop", 30 )
```

### Notes

- Any functions following the `Benchmark::MyFunc` format will be registered in the order they are defined
    - use `Benchmark._Add()` to manually register functions
    - All functions prefixed with an underscore are considered "internal" and will need to be manually registered
- Intended for solo testing/listen servers, dedicated is supported though.
    - Dedicated servers must do one of the following:
        - add "vscript_perf_warning_spew_ms" to their convar allowlist
        - set sv_allow_point_servercommand to "always"
        - manually set the convar to 0.0 and ignore the perf warnings for internal library functions
