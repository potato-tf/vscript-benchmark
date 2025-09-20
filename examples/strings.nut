// try { dofile( "benchmark.nut" ) } catch ( e ) { IncludeScript( "benchmark" ) }

local mins = Vector(-1, -2, -3)
local maxs = Vector(1, 2, 3)
local kvstring = ""
local str = "test"

// local chararray = @(input) array( input.len(), 0 ).apply( @( _, i ) input[i] )

// slow string comparison
// -----dump
// [000]     _OP_LOADINT 1 0 0 0
// [001]     _OP_LOADINT 2 10000 0 0
// [002]        _OP_JCMP 2 8 1 3
// [003]   _OP_PREPCALLK 2 "startswith" 0 3
// [004]    _OP_GETOUTER 4 0 0 0
// [005]        _OP_LOAD 5 "t" 0 0
// [006]        _OP_CALL 2 2 3 3
// [007]          _OP_JZ 2 1 0 0
// [008]    _OP_LOADBOOL 2 1 0 0
// [009]       _OP_PINCL 2 1 0 1
// [010]         _OP_JMP 0 -10 0 0
// [011]      _OP_RETURN 255 0 0 0
// -----
function Benchmark::StartsWith() {

    for ( local i = 0; i < 10000; i++ )
        if ( startswith( str, "t" ) )
            local len = true
}

// ~500-600% faster, simple integer comparison, no string _OP_LOAD, no function calls
// -----dump
// [000]     _OP_LOADINT 1 0 0 0
// [001]     _OP_LOADINT 2 10000 0 0
// [002]        _OP_JCMP 2 9 1 3
// [003]    _OP_GETOUTER 2 0 0 0
// [004]     _OP_LOADINT 3 0 0 0
// [005]         _OP_GET 2 2 3 0
// [006]     _OP_LOADINT 3 116 0 0
// [007]          _OP_EQ 2 3 2 0
// [008]          _OP_JZ 2 1 0 0
// [009]    _OP_LOADBOOL 2 1 0 0
// [010]       _OP_PINCL 2 1 0 1
// [011]         _OP_JMP 0 -11 0 0
// [012]      _OP_RETURN 255 0 0 0
// -----
function Benchmark::CharCompare() {

    for ( local i = 0; i < 10000; i++ )
        if ( str[0] == 't' )
            local len = true
}

// slow string concatenation, generates a ton of _OP_ADD/_OP_LOAD instructions
// -----dump
// [000]     _OP_LOADINT 1 0 0 0
// [001]     _OP_LOADINT 2 10000 0 0
// [002]        _OP_JCMP 2 30 1 3
// [003]    _OP_GETOUTER 2 1 0 0
// [004]        _OP_GETK 2 "x" 2 0
// [005]        _OP_LOAD 3 "," 0 0
// [006]         _OP_ADD 2 3 2 0
// [007]    _OP_GETOUTER 3 1 0 0
// [008]        _OP_GETK 3 "y" 3 0
// [009]         _OP_ADD 2 3 2 0
// [010]        _OP_LOAD 3 "," 0 0
// [011]         _OP_ADD 2 3 2 0
// [012]    _OP_GETOUTER 3 1 0 0
// [013]        _OP_GETK 3 "z" 3 0
// [014]         _OP_ADD 2 3 2 0
// [015]        _OP_LOAD 3 "," 0 0
// [016]         _OP_ADD 2 3 2 0
// [017]    _OP_GETOUTER 3 2 0 0
// [018]        _OP_GETK 3 "x" 3 0
// [019]         _OP_ADD 2 3 2 0
// [020]        _OP_LOAD 3 "," 0 0
// [021]         _OP_ADD 2 3 2 0
// [022]    _OP_GETOUTER 3 2 0 0
// [023]        _OP_GETK 3 "y" 3 0
// [024]         _OP_ADD 2 3 2 0
// [025]        _OP_LOAD 3 "," 0 0
// [026]         _OP_ADD 2 3 2 0
// [027]    _OP_GETOUTER 3 2 0 0
// [028]        _OP_GETK 3 "z" 3 0
// [029]         _OP_ADD 2 3 2 0
// [030]    _OP_SETOUTER 255 0 2 0
// [031]       _OP_PINCL 2 1 0 1
// [032]         _OP_JMP 0 -32 0 0
// [033]      _OP_RETURN 255 0 0 0
// -----
function Benchmark::StringConcat() {

    for ( local i = 0; i < 10000; i++ )
        kvstring = mins.x + "," + mins.y + "," + mins.z + "," + maxs.x + "," + maxs.y + "," + maxs.z
}

// ~40% faster, 2 instructions per format argument
// -----dump
// [000]     _OP_LOADINT 1 0 0 0
// [001]     _OP_LOADINT 2 10000 0 0
// [002]        _OP_JCMP 2 18 1 3
// [003]   _OP_PREPCALLK 2 "format" 0 3
// [004]        _OP_LOAD 4 "%g,%g,%g,%g,%g,%g" 0 0
// [005]    _OP_GETOUTER 5 1 0 0
// [006]        _OP_GETK 5 "x" 5 0
// [007]    _OP_GETOUTER 6 1 0 0
// [008]        _OP_GETK 6 "y" 6 0
// [009]    _OP_GETOUTER 7 1 0 0
// [010]        _OP_GETK 7 "z" 7 0
// [011]    _OP_GETOUTER 8 2 0 0
// [012]        _OP_GETK 8 "x" 8 0
// [013]    _OP_GETOUTER 9 2 0 0
// [014]        _OP_GETK 9 "y" 9 0
// [015]    _OP_GETOUTER 10 2 0 0
// [016]        _OP_GETK 10 "z" 10 0
// [017]        _OP_CALL 2 2 3 8
// [018]    _OP_SETOUTER 255 0 2 0
// [019]       _OP_PINCL 2 1 0 1
// [020]         _OP_JMP 0 -20 0 0
// [021]      _OP_RETURN 255 0 0 0
// -----
function Benchmark::StringFormat() {

    for ( local i = 0; i < 10000; i++ )
        kvstring = format("%g,%g,%g,%g,%g,%g", mins.x, mins.y, mins.z, maxs.x, maxs.y, maxs.z)

}

// faster than format for vectors/qangles, no _OP_GETK instructions
// -----dump
// [000]     _OP_LOADINT 1 0 0 0
// [001]     _OP_LOADINT 2 10000 0 0
// [002]        _OP_JCMP 2 12 1 3
// [003]   _OP_PREPCALLK 2 "format" 0 3
// [004]        _OP_LOAD 4 "%s %s" 0 0
// [005]    _OP_GETOUTER 5 1 0 0
// [006]   _OP_PREPCALLK 5 "ToKVString" 5 6
// [007]        _OP_CALL 5 5 6 1
// [008]    _OP_GETOUTER 6 2 0 0
// [009]   _OP_PREPCALLK 6 "ToKVString" 6 7
// [010]        _OP_CALL 6 6 7 1
// [011]        _OP_CALL 2 2 3 4
// [012]    _OP_SETOUTER 255 0 2 0
// [013]       _OP_PINCL 2 1 0 1
// [014]         _OP_JMP 0 -14 0 0
// [015]      _OP_RETURN 255 0 0 0
// -----
function Benchmark::StringKVStringFormat() {

    for (local i = 0; i < 10000; i++ )
        kvstring = format("%s %s", mins.ToKVString(), maxs.ToKVString())

}

// faster than previous, 3 or less _OP_ADD instructions is cheaper than 1 _OP_PREPCALLK/_OP_CALL for format()
// -----dump
// [000]     _OP_LOADINT 1 0 0 0
// [001]     _OP_LOADINT 2 10000 0 0
// [002]        _OP_JCMP 2 12 1 3
// [003]    _OP_GETOUTER 2 1 0 0
// [004]   _OP_PREPCALLK 2 "ToKVString" 2 3
// [005]        _OP_CALL 2 2 3 1
// [006]        _OP_LOAD 3 " " 0 0
// [007]         _OP_ADD 2 3 2 0
// [008]    _OP_GETOUTER 3 2 0 0
// [009]   _OP_PREPCALLK 3 "ToKVString" 3 4
// [010]        _OP_CALL 3 3 4 1
// [011]         _OP_ADD 2 3 2 0
// [012]    _OP_SETOUTER 255 0 2 0
// [013]       _OP_PINCL 2 1 0 1
// [014]         _OP_JMP 0 -14 0 0
// [015]      _OP_RETURN 255 0 0 0
// -----

function Benchmark::StringKVStringConcat() {

    for (local i = 0; i < 10000; i++ )
        kvstring = mins.ToKVString() + " " + maxs.ToKVString()
}


Benchmark._Start()