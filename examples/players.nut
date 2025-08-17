IncludeScript( "benchmark" )

local MAX_CLIENTS = MaxClients().tointeger()
local MAX_EDICTS = Constants.Server.MAX_EDICTS
local ALL_PLAYERS = {}
local player_manager = Entities.FindByClassname( null, "tf_player_manager" )

// to give these benchmarks the fairest chance
local Next  = Entities.Next.bindenv( Entities )
local First = Entities.First.bindenv( Entities )
local FindByClassname = Entities.FindByClassname.bindenv( Entities )

function Benchmark::ByClassname() {

    for ( local player; player = FindByClassname(player, "player"); )
        local temp = player
}

// fast enough for most use cases, noticeably faster than FindByClassname
function Benchmark::ByIndex() {

    for (local i = 1, player; i <= MAX_CLIENTS; i++)
        if ( player = PlayerInstanceFromIndex(i) )
            local temp = player
}

function Benchmark::TableIteration() {
    
    foreach ( player in ALL_PLAYERS )
        local temp = player
}

// // seemingly 5-10% faster
function Benchmark::FirstNextNoPlayer() {

    for (local ent = First(); ent; ent = Next(ent))
        if ( !ent.IsPlayer() )
            local temp = ent
}

function Benchmark::ByIndexNoPlayer() {

    for (local i = MAX_CLIENTS, ent; i <= MAX_EDICTS; i++)
        if ( ent = EntIndexToHScript(i) )
            local temp = ent
}

function Benchmark::InstanceOf() {

    for (local ent = First(); ent; ent = Next(ent))
        if ( ent instanceof CTFPlayer )
            local temp = ent
}

function Benchmark::Classname() {

    for (local ent = First(); ent; ent = Next(ent))
        if ( ent.GetClassname() == "player" )
            local temp = ent
}

function Benchmark::IsPlayer() {

    for (local ent = First(); ent; ent = Next(ent))
        if ( ent.IsPlayer() )
            local temp = ent
}


Benchmark.PlayerBenchmarkEvents <- {

    function OnGameEvent_player_team( params ) {

        if ( !ALL_PLAYERS.len() )
            for (local i = 1, player; i <= MAX_CLIENTS; i++)
                if ( player = PlayerInstanceFromIndex(i) )
                    ALL_PLAYERS[ player ] <- GetPropIntArray( player_manager, "m_iUserID", i )


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

Benchmark.Start()