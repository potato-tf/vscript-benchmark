IncludeScript( "benchmark" )

local MAX_CLIENTS = MaxClients().tointeger()
local MAX_EDICTS = Constants.Server.MAX_EDICTS

function Benchmark::ByClassname() {

    for (local player; player = Entities.FindByClassname(player, "player");)
        local temp = player
}

function Benchmark::ByIndex() {

    for (local i = 1, player; i <= MAX_CLIENTS; i++)
        if ( player = PlayerInstanceFromIndex(i) )
            local temp = player
}

// seemingly 5-10% faster
function Benchmark::FirstNextNoPlayer() {

    for (local ent = Entities.First(); ent; ent = Entities.Next(ent))
        if ( !ent.IsPlayer() )
            local temp = ent
}

function Benchmark::ByIndexNoPlayer() {

    for (local i = MAX_CLIENTS, ent; i <= MAX_EDICTS; i++)
        if ( ent = EntIndexToHScript(i) )
            local temp = ent
}

EntFire( "__benchmark", "CallScriptFunction", "Start" )