// copy/paste this try/catch for your benchmarks if you want vanilla squirrel support
try { 
    if ( !("Benchmark" in getroottable()) ) 
        dofile( "benchmark.nut" ) 
} 
catch ( e ) { 
    IncludeScript( "benchmark" ) 
}
/***********************************************************************************************************
 * FOLDING:                                                                                                *
 * Folding functions from their original scope into local/root scope is noticeably faster (~15-30%)        *
 * skips extra lookup instructions, also less verbose                                                      *
 ***********************************************************************************************************/
local GetPropString = NetProps.GetPropString.bindenv( NetProps )
local GetPropBool = NetProps.GetPropBool.bindenv( NetProps )

local _CONST = getconsttable()

// fold every pre-defined constant into the const table
if ( !( "ConstantNamingConvention" in ROOT ) )
	foreach( a, b in Constants )
		foreach( k, v in b )
            _CONST[k] <- v != null ? v : 0

setconsttable(_CONST)


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

function Benchmark::UnfoldedConst() {

    for (local i = 1; i <= Constants.Server.MAX_EDICTS; i++)
        local temp = i
}

function Benchmark::FoldedConst() {

    for (local i = 1; i <= MAX_EDICTS; i++)
        local temp = i
}

Benchmark._Start()