// copy/paste this try/catch for your benchmarks if you want vanilla squirrel support
try { 
    if ( !("Benchmark" in getroottable()) ) 
        dofile( "benchmark.nut" ) 
} 
catch ( e ) { 
    IncludeScript( "benchmark" ) 
}

Benchmark.FUNCTION_CALL_DELAY <- 0.5
Benchmark.MIN_PERF_WARNING_MS <- 0.0

local MAX_CLIENTS = MaxClients().tointeger()
// local MAX_EDICTS = Constants.Server.MAX_EDICTS
local MAX_EDICTS = 2048
::ALL_PLAYERS <- {}
local player_manager = Entities.FindByClassname( null, "tf_player_manager" )

// to give these benchmarks the fairest chance
local Next  = Entities.Next.bindenv( Entities )
local First = Entities.First.bindenv( Entities )
local FindByClassname = Entities.FindByClassname.bindenv( Entities )

// This is slower than byclassname for low player count/low edict maps
// but faster for high player count/high edict maps
function Benchmark::ByIndex() {

    for ( local i = 1, player; i <= MAX_CLIENTS; i++ )
        if ( player = PlayerInstanceFromIndex(i) )
            local temp = player.entindex()
}

function Benchmark::ByClassname() {

    for ( local player; player = FindByClassname(player, "player"); )
        local temp = player.entindex()
}

// faster than both to iterate a pre-collected table
function Benchmark::IterTable() {
    
    foreach ( player in ALL_PLAYERS.keys() )
        local temp = player.entindex()
}

// notably slower than FirstNext for low player count (one player) and low edict count (531 on mvm_bigrock)
// probably better on 100 player? untested, run it with 100 bots and see
function Benchmark::ByIndexNoPlayer() {

    for (local i = MAX_CLIENTS, ent; i <= MAX_EDICTS; ent = EntIndexToHScript(i), i++)
        if ( ent )
            local temp = ent.entindex()
}

// significantly faster on low player/edict count
// also untested on 100 player
function Benchmark::FirstNextNoPlayer() {

    for (local ent = First(); ent; ent = Next(ent))
        if ( !ent.IsPlayer() )
            local temp = ent.entindex()
}

// slow
function Benchmark::Classname() {

    for (local ent = First(); ent; ent = Next(ent))
        if ( ent.GetClassname() == "player" )
            local temp = ent.entindex()
}

// faster
function Benchmark::InstanceOf() {

    for (local ent = First(); ent; ent = Next(ent))
        if ( ent instanceof CTFPlayer )
            local temp = ent.entindex()
}

// fastest
function Benchmark::IsPlayer() {

    for (local ent = First(); ent; ent = Next(ent))
        if ( ent.IsPlayer() )
            local temp = ent.entindex()
}


Benchmark.PlayerBenchmarkEvents <- {

    function OnGameEvent_player_spawn( params ) {

        if ( !ALL_PLAYERS.len() )
            for (local i = 1, player; i <= MAX_CLIENTS; i++)
                if ( player = PlayerInstanceFromIndex(i) )
                    ALL_PLAYERS[ player ] <- NetProps.GetPropIntArray( player_manager, "m_iUserID", i )


        local player = GetPlayerFromUserID( params.userid )

        if ( !( player in ALL_PLAYERS ) )
            ALL_PLAYERS[ player ] <- params.userid
    }

    function OnGameEvent_player_disconnect( params ) {

        local player = GetPlayerFromUserID( params.userid )

        if ( player in ALL_PLAYERS )
            delete ALL_PLAYERS[ player ]
    }
}

__CollectGameEventCallbacks( Benchmark.PlayerBenchmarkEvents )

Benchmark._Start()