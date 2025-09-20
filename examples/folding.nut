try { dofile( "benchmark.nut" ) } catch ( e ) { IncludeScript( "benchmark" ) }

local GetPropString = NetProps.GetPropString.bindenv( NetProps )
// local MAX_EDICTS = Constants.Server.MAX_EDICTS
local MAX_EDICTS = 2048

function Benchmark::Unfolded() {

    for ( local i = 0, ent; i < Constants.Server.MAX_EDICTS; ent = EntIndexToHScript( i ), i++ ) {

        if ( ent ) {

            NetProps.GetPropString( ent, "m_iName" )
            NetProps.GetPropString( ent, "m_iClassname" )
            NetProps.GetPropBool( ent, "m_bForcePurgeFixedupStrings" )
        }
    }
}

// 20% faster, maybe more
function Benchmark::Folded() {

    for ( local i = 0, ent; i < MAX_EDICTS; ent = EntIndexToHScript( i ), i++ ) {

        if ( ent ) {

            GetPropString( ent, "m_iName" )
            GetPropString( ent, "m_iClassname" )
            GetPropBool( ent, "m_bForcePurgeFixedupStrings" )
        }
    }
}

Benchmark._Start()