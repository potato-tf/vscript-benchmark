IncludeScript( "benchmark" )

local arr = array( 1000 )

// function Benchmark::Len() {

//     for ( local i = 0; i < 1000; i++ )
//         if ( arr.len() == 1000 )
//             local len = true
// }

// function Benchmark::Idx() {

//     for ( local i = 0; i < 1000; i++ )
//         if ( 999 in arr && !(1000 in arr) )
//             local len = true
// }

// function Benchmark::LenExplicit() {

//     for ( local i = 0; i < 1000; i++ )
//         if ( arr.len() != 0 )
//             local len = true
// }

// function Benchmark::LenFalsy() {
    
//     for ( local i = 0; i < 1000; i++ )
//         if ( arr.len() )
//             local len = true
// }


function Benchmark::ForLoop() {

    local _arr = clone arr
    local temp = null

    for ( local i = 0; i < _arr.len(); i++ )
        i * 2
}

// almost 3x faster apparently
function Benchmark::ForEach() {

    local _arr = clone arr
    local temp = null

    foreach ( i, v in _arr )
        i * 2
}

function Benchmark::ApplyLambda() {

    local _arr = clone arr
    local temp = null

    _arr.apply( @(v, i) i * 2 )
}

EntFire( "__benchmark", "CallScriptFunction", "_Start" )