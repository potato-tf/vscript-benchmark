// generate dummy vscript api calls used in the benchmark script to run for sq.exe bytecode dumps
// DO NOT USE THIS IN-GAME, ONLY USE THIS FOR BYTECODE DUMPS

// IncludeScript( "popextensions/WIP/vscript_api_documentation" )
try { dofile( "./vscript_api_documentation.nut", true ) } catch (e) IncludeScript( "vscript_api_documentation" )

function UniqueString( suffix = "" ) {

    local arr = array( 8 ).apply( @(_) 90 * rand() / RAND_MAX )
    local str = "_"

    foreach ( i, t in arr )
        str += format( "%02x", t )

    return format( "%s_%s", str, suffix )
}

function printl( msg ) { print(msg+"\n") }

::DummyEnt <- class {

    name      = ""
    script_id = ""
    scope = null

    GetName        = @() name
    GetScriptScope = @() scope
    GetScriptId    = @() script_id

    constructor( _name = "__benchmark_dummy" ) {

        this.name = _name
        this.script_id = UniqueString( _name.slice(1) )
        this.scope = {
            self = this
            __vrefs = 1
            __vname = this.script_id
        }
    }
}

foreach ( method in VSCRIPT_API_DOCS.ScriptFunctions.CBaseEntity.keys() )
    if ( !(method in DummyEnt) )
        DummyEnt[method] <- @(...) null

::Vector <- class {

    x = 0.0
    y = 0.0
    z = 0.0

    constructor( x = 0.0, y = 0.0, z = 0.0 ) {

        this.x = x
        this.y = y
        this.z = z
    }

    Cross       = @(...) Vector()
    Scale       = @(...) Vector()
    Dot         = @(...) 0.0
    Length      = @(...) 0.0
    LengthSqr   = @(...) 0.0
    Length2D    = @(...) 0.0
    Length2DSqr = @(...) 0.0
    Norm        = @(...) 1.0
    ToQuat      = @(...) null
    tostring    = @() ToKVString()
    ToKVString  = @() format( "%g %g %g", x, y, z )
}

::QAngle <- Vector

local doc_to_type = {

    void   = null
    any    = null
    handle = null
    int    = 0
    bool   = false
    float  = 0.0
    string = ""
    table  = {}
    array  = []
    Vector = Vector()
    QAngle = QAngle()
}

foreach ( cls, methods in VSCRIPT_API_DOCS.ScriptFunctions ) {

    if ( !(cls in __ROOT) )
        __ROOT[cls] <- methods

    foreach ( method, info in methods ) {

        local return_type = strip( split( info.info, " " )[0] ).slice(1)
        local return_val  = null

        // convert to valid squirrel type
        if ( return_type in doc_to_type ) {
            return_val = return_type == "table" || return_type == "array" ? clone doc_to_type[return_type] : doc_to_type[return_type]
        }

        // uppercase type is a class instance
        else if (return_type[0] < 'a' ) 
            return_val = null

        if ( cls != "Globals" )    
            __ROOT[cls][method] <- @( ... ) return_val
    
        else if ( !( method in __ROOT ) )
            __ROOT[method] <- @( ... ) return_val
    }
}

foreach ( cls, inst in { CEntities = "Entities", CScriptEntityOutputs = "EntityOutputs", CNavMesh = "NavMesh", CNetPropManager = "NetProps", CPlayerVoiceListener = "PlayerVoiceListener" } )
    if ( cls in __ROOT )
        __ROOT[inst] <- __ROOT[cls]

// class NetProps {

//     GetPropInt         = @(...) -1
//     GetPropBool        = @(...) false
//     GetPropFloat       = @(...) -1.0
//     GetPropString      = @(...) ""
//     GetPropEntity      = @(...) null
//     GetPropVector      = @(...) Vector()

//     GetPropIntArray    = @(...) -1
//     GetPropBoolArray   = @(...) false
//     GetPropFloatArray  = @(...) -1.0
//     GetPropStringArray = @(...) ""
//     GetPropEntityArray = @(...) null
//     GetPropVectorArray = @(...) Vector()

//     GetPropType        = @(...) "null"
//     GetTable           = @(...) {}
//     GetPropInfo        = @(...) null
//     GetPropArraySize   = @(...) 0

//     HasProp            = @(...) false
//     IsValid            = @(...) false

//     SetPropBool        = @(...) null
//     SetPropFloat       = @(...) null
//     SetPropStringArray = @(...) null
//     SetPropFloatArray  = @(...) null
//     SetPropEntity      = @(...) null
//     SetPropString      = @(...) null
//     SetPropVectorArray = @(...) null
//     SetPropInt         = @(...) null
//     SetPropEntityArray = @(...) null
//     SetPropVector      = @(...) null
//     SetPropBoolArray   = @(...) null
//     SetPropIntArray    = @(...) null
// }


// foreach ( override in overrides )
//     __ROOT[override] <- @(...) null