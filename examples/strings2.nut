// copy/paste this try/catch for your benchmarks if you want vanilla squirrel support
try { 
    if ( !("Benchmark" in getroottable()) ) 
        dofile( "benchmark.nut" ) 
} 
catch ( e ) { 
    IncludeScript( "benchmark" ) 
}

Benchmark.LOOP_RESTART_DELAY <- 1.0

local map_name = GetMapName()
local prefixtrue = "mvm_bigrock"
local prefixfalse = "workshop/"

function startswith_evil( str, prefix, prefixlen ) {

    if ( str[0] != prefix[0] || !( prefixlen in str ) || str[prefixlen] != prefix[prefixlen] )
        return false

    for ( local behind = 1, ahead = prefixlen >> 1; behind; behind = prefixlen - ahead, ahead++ )
        if ( str[ahead] != prefix[ahead] || str[behind] != prefix[behind] )
            return false

    return true
}
function startswith_evil2( str, prefix, prefixlen ) {

    if ( str[0] != prefix[0] )
        return false
    
    else if ( !( prefixlen in str ) )
        return false
    
    else if ( str[prefixlen] != prefix[prefixlen] )
        return false
    
    for ( local behind = 1, ahead = prefixlen >> 1; behind; behind = prefixlen - ahead, ahead++ )
        if ( str[ahead] != prefix[ahead] )
            return false
        else if ( str[behind] != prefix[behind] )
            return false

    return true
}

// local chararray = @(input) array( input.len(), 0 ).apply( @( _, i ) input[i] )

function Benchmark::StartsWithTrue()
    for (local i = 0; i < 100; i++)
        startswith( map_name, prefixtrue )

function Benchmark::StartsWithEvilTrue()
    for (local i = 0; i < 100; i++)
        startswith_evil( map_name, prefixtrue, 11 )

function Benchmark::StartsWithEvil2True()
    for (local i = 0; i < 100; i++)
        startswith_evil2( map_name, prefixtrue, 11 )


function Benchmark::StartsWithFalse()
    for (local i = 0; i < 100; i++)
        startswith( map_name, prefixfalse )

function Benchmark::StartsWithEvilFalse()
    for (local i = 0; i < 100; i++)
        startswith_evil( map_name, prefixfalse, 11 )

function Benchmark::StartsWithEvil2False()
    for (local i = 0; i < 100; i++)
        startswith_evil2( map_name, prefixfalse, 11 )


// function Benchmark::AppendStr() {

//     local joined = ""
//     local ignored = array( 10, "" ).apply( @( _, i ) i.tostring() )

//     local l = ignored.len() - 1
//     for (local i = 0; i < l; i++)
//         joined += ignored[i] + " "

//     joined += ignored[l]
// }

// function Benchmark::SliceLast() {

//     local joined = ""
//     local ignored = array( 10, "" ).apply( @( _, i ) i.tostring() )

//     foreach ( word in ignored )
//         joined += word + " "

//     joined = joined.slice( 0, -1 )
// }

// function Benchmark::RunGC() {
//     collectgarbage()
// }


Benchmark._Start()