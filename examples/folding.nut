IncludeScript( "benchmark" )

local GetPropString = NetProps.GetPropString.bindenv( NetProps )
local MAX_EDICTS = Constants.Server.MAX_EDICTS

function Benchmark::Unfolded() {

    for ( local i = 0, ent; i < Constants.Server.MAX_EDICTS; ent = EntIndexToHScript( i ), i++ ) {

        if ( ent ) {

            NetProps.GetPropString( ent, "m_iName" )
            NetProps.GetPropString( ent, "m_iName" )
            NetProps.GetPropString( ent, "m_iName" )
        }
    }
}

// 20% faster, maybe more
function Benchmark::Folded() {

    for ( local i = 0, ent; i < MAX_EDICTS; ent = EntIndexToHScript( i ), i++ ) {

        if ( ent ) {

            GetPropString( ent, "m_iName" )
            GetPropString( ent, "m_iName" )
            GetPropString( ent, "m_iName" )
        }
    }
}

Benchmark.Testing <- function() {

    for ( local i = 0; i < 1000; i++ )
        i * 2
}

EntFire( "__benchmark", "CallScriptFunction", "Start" )