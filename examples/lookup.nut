// copy/paste this try/catch at the top of the script to initialize everything.
try { if ( !("Benchmark" in getroottable()) ) dofile( "benchmark.nut" ) } catch ( e ) { IncludeScript( "benchmark" ) }

::SomeGlobalVar <- 0
const GLOBAL_VAR = 0x7FFFFFFF

function Benchmark::_OnDestroy() { delete ::SomeGlobalVar; delete getconsttable().GLOBAL_VAR }

function Benchmark::SlowIncrement()
{
    for (local i = 1; i <= 1000; i++)
        SomeGlobalVar++
}

// 10x faster!?
function Benchmark::FastIncrement()
{
    local myvar = 0

    for (local i = 1; i <= 1000; i++)
        myvar++

    SomeGlobalVar += myvar
}

function Benchmark::NormalLookup() {

    for (local i = 1; i <= 1000; i++)
        SomeGlobalVar++
}

// 10x faster!?
function Benchmark::RootLookup() {

    for (local i = 1; i <= 1000; i++)
        ::SomeGlobalVar++
}

function Benchmark::RootSetLookup() {

    for (local i = 1; i <= 10000; i++)
        local temp = ::SomeGlobalVar
}

// ~20-40% faster
function Benchmark::ConstSetLookup() {

    for (local i = 1; i <= 10000; i++)
        local temp = GLOBAL_VAR
}

Benchmark._Start()