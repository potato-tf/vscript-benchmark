IncludeScript( "benchmark" )

local mins = Vector(-1, -2, -3)
local maxs = Vector(1, 2, 3)
local kvstring = ""

function Benchmark::StringConcat() {

    for ( local i = 0; i < 10000; i++ )
        kvstring = mins.x.tostring() + "," + mins.y.tostring() + "," + mins.z.tostring() + "," + maxs.x.tostring() + "," + maxs.y.tostring() + "," + maxs.z.tostring()
}

// ~40% faster
function Benchmark::StringFormat() {

    for ( local i = 0; i < 10000; i++ )
        kvstring = format("%g,%g,%g,%g,%g,%g", mins.x, mins.y, mins.z, maxs.x, maxs.y, maxs.z)

}

// faster than format for vectors/qangles
function Benchmark::StringKVStringFormat() {

    for (local i = 0; i < 10000; i++ )
        kvstring = format("%s %s", mins.ToKVString(), maxs.ToKVString())

}

// somehow even faster?
function Benchmark::StringKVStringConcat() {

    for (local i = 0; i < 10000; i++ )
        kvstring = mins.ToKVString() + " " + maxs.ToKVString()
}


EntFire( "__benchmark", "CallScriptFunction", "_Start" )