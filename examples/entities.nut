IncludeScript( "benchmark" )

Benchmark.LOOP_RESTART_DELAY <- 10

local CreateByClassname = Entities.CreateByClassname.bindenv( Entities )
local SetPropBool = NetProps.SetPropBool.bindenv( NetProps )
local SetPropString = NetProps.SetPropString.bindenv( NetProps )
local DispatchSpawn = Entities.DispatchSpawn.bindenv( Entities )
local MAX_CLIENTS = MaxClients().tointeger()
local MAX_EDICTS = Constants.Server.MAX_EDICTS

function Benchmark::EntityGroupFromTable() {

    // spawn origins are right outside of bigrock spawn
    SpawnEntityGroupFromTable({
        [0] = {
            func_rotating =
            {
                message = "hl1/ambience/labdrone2.wav",
                volume = 8,
                responsecontext = "-1 -1 -1 1 1 1",
                targetname = "crystal_spin",
                vscripts = "rotatefix", // see func_rotating vdc page for this
                spawnflags = 65,
                solidbsp = 0,
                rendermode = 10,
                rendercolor = "255 255 255",
                renderamt = 255,
                maxspeed = 48,
                fanfriction = 20,
                origin = Vector(278.900513, -2033.692993, 516.067200),
            }
        },
        [2] = {
            tf_glow =
            {
                targetname = "crystalglow",
                parentname = "crystal",
                target = "crystal",
                Mode = 2,
                origin = Vector(278.900513, -2033.692993, 516.067200),
                GlowColor = "0 78 255 255"
            }
        },
        [3] = {
            prop_dynamic =
            {
                targetname = "crystal",
                solid = 6,
                renderfx = 15,
                rendercolor = "255 255 255",
                renderamt = 255,
                physdamagescale = 1.0,
                parentname = "crystal_spin",
                modelscale = 1.3,
                model = "models/props_moonbase/moon_gravel_crystal_blue.mdl",
                MinAnimTime = 5,
                MaxAnimTime = 10,
                fadescale = 1.0,
                fademindist = -1.0,
                origin = Vector(278.900513, -2033.692993, 516.067200),
                angles = QAngle(45, 0, 0)
            }
        },
    })
}

function Benchmark::PointScriptTemplate() {

    local script_template = Entities.CreateByClassname("point_script_template")

    script_template.AddTemplate("func_rotating", {
        message = "hl1/ambience/labdrone2.wav",
        volume = 8,
        targetname = "crystal_spin2",
        spawnflags = 65,
        solidbsp = 0,
        rendermode = 10,
        rendercolor = "255 255 255",
        vscripts = "rotatefix",
        renderamt = 255,
        maxspeed = 48,
        fanfriction = 20,
        origin = Vector(175.907211, -2188.908691, 516.031311),
    })

    script_template.AddTemplate("tf_glow", {
            target = "crystal2",
            Mode = 2,
            origin = Vector(175.907211, -2188.908691, 516.031311),
            GlowColor = "0 78 255 255"
    })

    script_template.AddTemplate("prop_dynamic", {
        targetname = "crystal2",
        solid = 6,
        renderfx = 15,
        rendercolor = "255 255 255",
        renderamt = 255,
        physdamagescale = 1.0,
        parentname = "crystal_spin2",
        modelscale = 1.3,
        model = "models/props_moonbase/moon_gravel_crystal_blue.mdl",
        MinAnimTime = 5,
        MaxAnimTime = 10,
        fadescale = 1.0,
        fademindist = -1.0,
        origin = Vector(175.907211, -2188.908691, 516.031311),
        angles = QAngle(45, 0, 0)
    })

    script_template.AcceptInput( "ForceSpawn", null, null, null )
}

function Benchmark::ByClassname() {

    for (local i = 0; i < 100; i++) {

        local ent = CreateByClassname("logic_relay")
        DispatchSpawn( ent )
        SetPropString( ent, "m_iName", "__relay" )
    }
}

function Benchmark::FromTable() {

    for (local i = 0; i < 100; i++) {

        SpawnEntityFromTable("logic_relay", { targetname = "__relay" })
    }
}

function Benchmark::Done() {

    EntFire( "__relay", "Kill" )
    EntFire( "crystal*", "Kill" )
}

function InstanceOf() {

    for (local ent = Entities.First(); ent; ent = Entities.Next(ent))
        if ( ent instanceof CTFPlayer )
            local temp = ent
}

function Classname() {

    for (local ent = Entities.First(); ent; ent = Entities.Next(ent))
        if ( ent.GetClassname() == "player" )
            local temp = ent
}

function IsPlayer() {

    for (local ent = Entities.First(); ent; ent = Entities.Next(ent))
        if ( ent.IsPlayer() )
            local temp = ent
}
Benchmark.Add( IsPlayer, 1 )
Benchmark.Add( InstanceOf, 1.5 )
Benchmark.Add( Classname, 2 )
Benchmark.Add( Classname, 2.5 )
Benchmark.Add( Classname, 3 )

EntFire( "__benchmark", "CallScriptFunction", "Start" )