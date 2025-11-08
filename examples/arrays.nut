// copy/paste this try/catch at the top of the script to initialize everything.
try { if ( !("Benchmark" in getroottable()) ) dofile( "benchmark.nut" ) } catch ( e ) { IncludeScript( "benchmark" ) }

/************************************************************************************************
 * ARRAYS:                                                                                      *
 * Squirrel's .len() function can be expensive.                                                 *
 * Direct index lookups are generally much faster, skipping _OP_PREPCALLK/_OP_CALL instructions *
 * NEVER use .len() inside a for loop.  Always cache it off before looping.                     *
 * (This doesn't apply to backwards looping e.g. starting at array.len() - 1 and decrementing)  *
 ************************************************************************************************/

Benchmark.LOOP_RESTART_DELAY <- 3.0

local arr = array( 1000 )
local arr_len = arr.len()

/*****************
 * LENGTH CHECKS *
 *****************/
function Benchmark::Len() {

    for ( local i = 0; i < 1000; i++ )
        if ( arr.len() == 1000 )
            local len = true
}

// ~40% faster, no _OP_PREPCALLK/_OP_CALL instructions
function Benchmark::Idx() {

    for ( local i = 0; i < 1000; i++ )
        if ( 999 in arr && !(1000 in arr) )
            local len = true
}

/****************************
 * EMPTY ARRAY/TABLE CHECKS *
 ****************************/
function Benchmark::LenExplicit() {

    for ( local i = 0; i < 1000; i++ )
        if ( arr.len() != 0 )
            local len = true
}

// ~2-5% faster, no _OP_NE instruction
function Benchmark::LenFalsy() {
    
    for ( local i = 0; i < 1000; i++ )
        if ( arr.len() )
            local len = true
}

/*******************
 * ARRAY ITERATION *
 *******************/

// standard for loop
// NOTE: if we used arr.len() we would be 300% slower, due to an additional _OP_PREPCALLK/_OP_CALL instruction every iteration
// caching the length changes this to a single _OP_GETOUTER
// -----dump
// [000]     _OP_LOADINT 1 0 0 0
// [001]    _OP_GETOUTER 2 0 0 0
// [002]        _OP_JCMP 2 4 1 3
// [003]     _OP_LOADINT 2 2 0 0
// [004]         _OP_MUL 2 2 1 0
// [005]       _OP_PINCL 2 1 0 1
// [006]         _OP_JMP 0 -6 0 0
// [007]      _OP_RETURN 255 0 0 0
// -----
function Benchmark::ForLoop() { for ( local i = 0; i < arr_len; i++ ) i * 2 }

// ~1-4% faster than for loop
// NOTE: inconsistent results, will occasionally spike much higher than ForLoop
// (likely GC hits?)
// function Benchmark::ApplyLambda() { arr.apply( @(v, i) i * 2 ) }

// slightly faster, specialized _OP_FOREACH instruction that doesn't use _OP_JCMP
// -----dump
// [000]    _OP_GETOUTER 1 0 0 0
// [001]   _OP_LOADNULLS 2 3 0 0
// [002]     _OP_FOREACH 1 4 2 0
// [003] _OP_POSTFOREACH 1 4 2 0
// [004]     _OP_LOADINT 5 2 0 0
// [005]         _OP_MUL 5 5 2 0
// [006]         _OP_JMP 0 -5 0 0
// [007]      _OP_RETURN 255 0 0 0
// -----
function Benchmark::ForEach() { foreach ( i, v in arr ) i * 2 }

// same as ForLoop
// function Benchmark::WhileLoop() { local i = 0; while ( i < arr.len() ) { i * 2; i++ } }

function Benchmark::Append() {

    local arr = []

    for ( local i = 0; i < 10000; i++ )
        arr.append( i )
}

// 100-200% faster than appending if you already know the size of the array
function Benchmark::PreSizedArray() {

    local arr = array( 10000 )
    for ( local i = 0; i < 10000; i++ )
        arr[i] = i
}

function Benchmark::PreSizedArray2() {

    local arr = array( 10000 )
    local i = 0
    while ( i < 10000 )
        arr[i++] = i

    printl( arr[0] + " : " + arr[9999] )
}

function Benchmark::PreSizedArray3() {

    local arr = array( 10000 )
    local i = 0
    while ( i < 9999 )
        arr[++i] = i

    printl( arr[0] + " : " + arr[9999] )
}
Benchmark._Start()

// Benchmark.ForLoop()
// Benchmark.ForEach()