if ( "Benchmark" in getroottable() )
    return

SendToConsole( "developer 0" )
error("\n\n==================================================\n= ")
print("VScript Benchmarking Script")
error("                    =\n= ")
print("By ")
error("Braindawg                                   =\n= ")
print("https://github.com/potato-tf/vscript-benchmark")
error(" =\n==================================================\n\n")

/**********
 * CONFIG *
 **********/
local config = {

    // sets mat_queue_mode 0 while script is active
    NO_MULTITHREADING  = true

    // default delay between function calls
    FUNCTION_CALL_DELAY = 1

    // default delay between full benchmark loop restarts
    LOOP_RESTART_DELAY = 3

    // automatically disable perf warnings for excluded functions
    AUTO_PERF_COUNTER = true

    // automatically add Benchmark scoped functions to the benchmark loop in the order they are defined
    AUTO_ADD_FUNCTIONS = true

    // filter text in the console
    FILTER_TEXT = true
}
/************************************************************
 * CONSTANTS                                                *
 * use locals instead to avoid polluting the constant table *
 ************************************************************/

// put this one in root so other scripts can use it
::__ROOT  <- getroottable()

// String caching for strings used more than once
local BENCHMARK_PREFIX    = "[BENCHMARK] "
local PERF_COUNTER_CVAR   = "vscript_perf_warning_spew_ms"
local MT_MESSAGE          = format( "%s Disabling multithreading to fix console messages", BENCHMARK_PREFIX )
local TRIGGER_INPUT       = "Trigger"
local CANCEL_PENDING      = "CancelPending"
local ON_TRIGGER          = "OnTrigger"
local CALL_FUNCTION       = "CallScriptFunction"
local FUNCTION_TYPE       = "function"
local RESTART_LOOP        = "__RestartLoop"
local END_LOOP            = "__EndLoop"
local __                  = "_"
local BENCHMARK_START     = "========= BENCHMARK START ========="
local BENCHMARK_END       = "========== BENCHMARK END ==========\n\n"

local IS_DEDICATED        = IsDedicatedServer()
local CONVAR_ON_ALLOWLIST = Convars.IsConVarOnAllowList( PERF_COUNTER_CVAR )

// re-define for performance/simplicity
local SetConvar           = Convars.SetValue.bindenv( Convars )
local GetConvar           = Convars.GetStr.bindenv( Convars )
local GetConvarInt        = Convars.GetInt.bindenv( Convars )
local GetConvarFloat      = Convars.GetFloat.bindenv( Convars )

local CreateByClassname   = Entities.CreateByClassname.bindenv( Entities )
local AddOutput           = EntityOutputs.AddOutput.bindenv( EntityOutputs )
local RemoveOutput        = EntityOutputs.RemoveOutput.bindenv( EntityOutputs )
local GetNumElements      = EntityOutputs.GetNumElements.bindenv( EntityOutputs )
local GetOutputTable      = EntityOutputs.GetOutputTable.bindenv( EntityOutputs )

/**********************************************************************************************************
 * BENCHMARK ENTITY                                                                                       *
 * we're not doing the delay and looping logic in vscript to avoid tripping the perf counter ourselves    *
 * logic_relay handles delays, cancelling, and looping just fine                                          *
 **********************************************************************************************************/
local benchmark_ent = SpawnEntityFromTable( "logic_relay", { targetname = "__benchmark" vscripts = " " })
NetProps.SetPropBool( benchmark_ent, "m_bForcePurgeFixedupStrings", true )

/****************************************
 * BENCHMARK SCOPE                      *
 * all functions must be scoped to this *
 ****************************************/
::Benchmark <- benchmark_ent.GetScriptScope()

foreach ( k, v in config )
    Benchmark[ k ] <- v

// Misc internal variables
Benchmark.__loop_delay   <- Benchmark.LOOP_RESTART_DELAY // delay between loop restarts
Benchmark.__restart      <- false // reload the benchmark system after it's killed
Benchmark.__active_benchmarks <- {} // track active benchmarks

local function_blacklist = {

    Call                = null
    DispatchPrecache    = null
    DispatchOnPostSpawn = null
}

// original perf warning value before we changed it
if ( Benchmark.AUTO_PERF_COUNTER )
    Benchmark.__perf_warning_ms <- GetConvarFloat( PERF_COUNTER_CVAR )

 // original mat_queue_mode value before we changed it
if ( Benchmark.NO_MULTITHREADING || Benchmark.FILTER_TEXT )
    Benchmark.__mat_queue_mode  <- GetConvarInt( "mat_queue_mode" )

// Ghetto constructor/destructor logic using table metamethods
// automatically adds functions to the benchmark loop in the order they're defined
benchmark_ent.GetScriptScope().setdelegate({

        delay = Benchmark.FUNCTION_CALL_DELAY
        function _newslot( k, v ) {

            if ( k == "_BenchmarkDestroy" && _BenchmarkDestroy == null )
                _BenchmarkDestroy = v.bindenv( Benchmark )

            Benchmark.rawset( k, v )

            if ( k == "_BenchmarkInit" )
                _BenchmarkInit()

            else if (
                Benchmark.AUTO_ADD_FUNCTIONS
                && typeof v == FUNCTION_TYPE
                && !startswith( k, __ )
                && !startswith( k, "Input" )
                && !startswith( k, "Filter_" )
                && !(k in function_blacklist)
            ) {
                _Add( k, delay )
                delay += Benchmark.FUNCTION_CALL_DELAY
            }
        }

    }.setdelegate({

        parent = Benchmark.getdelegate()
        id     = benchmark_ent.GetScriptId()
        _BenchmarkDestroy = null

        function _get( k ) {

            return parent[k]
        }

        function _delslot( k ) {

            if ( k == id ) {
                
                if ( _BenchmarkDestroy )
                    _BenchmarkDestroy()

                delete ::Benchmark
            }
            delete parent[k]
        }
    })
)

/*************
 * FUNCTIONS *
 ************/

// console command wrapper
function Benchmark::_ConsoleCmd( cmd = PERF_COUNTER_CVAR, value = 1.5 ) {

    if ( value == null )
        return GetConvar( cmd )

    if ( !IS_DEDICATED )
        SendToConsole( format( "%s %.8f", cmd, value ) )

    else if ( CONVAR_ON_ALLOWLIST )
        SetConvar( cmd, value )

    else if ( GetConvar( "sv_allow_point_servercommand" ) == "always" )
        SendToServerConsole( format( "%s %.8f", cmd, value ) )
}

function Benchmark::_Print( msg ) {

    printl( msg )
    if ( IS_DEDICATED )
        ClientPrint( null, 2, msg )
}

function Benchmark::_BenchmarkInit() {

    // if ( AUTO_PERF_COUNTER )
        // _ConsoleCmd( PERF_COUNTER_CVAR, 999 )

    if ( !IS_DEDICATED && ( NO_MULTITHREADING || FILTER_TEXT ) && __mat_queue_mode ) {

        ClientPrint( null, 3, MT_MESSAGE )
        ClientPrint( null, 4, MT_MESSAGE )
        SendToConsole( "mat_queue_mode 0" )
    }

    if ( FILTER_TEXT ) {

        SendToConsole( "con_filter_enable 2" )
    } 
    else {

        SendToConsole( "con_filter_enable 1" )
        SendToConsole( "con_filter_text \"\"" )
    }
    // always filter this one out
    SendToConsole( "con_filter_text_out _get" )

    __filename <- getstackinfos( 2 ).src
}

function Benchmark::_BenchmarkDestroy() {

    if ( __restart )
        EntFire( "BigNet", "RunScriptFile", format( "benchmarks/%s", __filename ), 0.2 )

    if ( AUTO_PERF_COUNTER )
        _ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )

    if ( FILTER_TEXT )
        SendToConsole( "con_filter_enable 0" )

    if ( "__ROOT" in getroottable() )
        delete ::__ROOT
}

function Benchmark::_ValidateFunc( func ) {

    local func_name = typeof func == FUNCTION_TYPE ? func.getinfos().name : func

    return typeof func == FUNCTION_TYPE
        && !startswith( func_name, __ )
        && !startswith( func_name, "Input" )
        && !startswith( func_name, "Filter_" )
        && !( func_name in function_blacklist )
}

/***********************************************************************
 * Get function reference and configure scoping for the benchmark loop *
 * Accepts string or function reference                                *
 * if name_only is true, only the function name will be returned       *
 ***********************************************************************/
function Benchmark::_GetFunc( func, name_only = false ) {

    if ( typeof func == "string" ) {

        if ( !(func in Benchmark) )
            if ( func in __ROOT )
                Benchmark[ func ] <- __ROOT[ func ]
            else
                Assert( false, format( "%s Function not found: %s", BENCHMARK_PREFIX, func ) )

        func = Benchmark[ func ]
    }

    if ( typeof func != FUNCTION_TYPE )
        Assert( false, format( "%s Not a function: %s", BENCHMARK_PREFIX, func.tostring() ) )

    local func_name = func.getinfos().name

    if ( !(func_name in Benchmark) )
        Benchmark[ func_name ] <- func

    if ( FILTER_TEXT ) {

        compilestring(format(@"

            function Benchmark::Filter_%s() { SendToConsole( %s ) }
        ", func_name, format( "\"con_filter_text %s\"", func_name) ) )()
    }


    return name_only ? func_name : func
}

/****************************************
 * Add a function to the benchmark loop *
 * Accepts string or function reference *
 ****************************************/
function Benchmark::_Add( func, delay = Benchmark.FUNCTION_CALL_DELAY ) {

    local func_name = _GetFunc( func, true )

    // if ( func_name in __active_benchmarks && AUTO_ADD_FUNCTIONS )
        // return

    // apparently !self doesn't work in AddOutput
    if ( FILTER_TEXT ) {
        AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, format( "Filter_%s", func_name ), delay, -1 )
        delay += 0.1
    }
    AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, func_name, delay, -1 )

    __active_benchmarks[ func_name ] <- func

    if ( delay > __loop_delay )
        __loop_delay = delay
}

/******************************************
 * Run the benchmark loop once, then stop *
 ******************************************/
function Benchmark::_StartOnce() {

    benchmark_ent.AcceptInput( TRIGGER_INPUT, null, null, null )
}

/**********************************************************
 * Start the benchmark loop.  Stop the loop with _StopAll *
 **********************************************************/
function Benchmark::_Start() {
    __StartLoop()
}

/************************************************************************************
 * Find all functions in the Benchmark scope/namespace and start the benchmark loop *
 ************************************************************************************/
function Benchmark::_StartAll( delay = Benchmark.FUNCTION_CALL_DELAY ) {

    foreach ( name, func in Benchmark )
        if ( _ValidateFunc( func ) )
            _Add( name, delay++ )
    
    __StartLoop()
}

/*****************************************************
 * Stop the benchmark loop                           *
 * wipe = true will clear all queued benchmark calls *
 *****************************************************/
function Benchmark::_StopAll( wipe = false ) {

    _ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )
    benchmark_ent.AcceptInput( CANCEL_PENDING, null, null, null )
    __loop_delay = LOOP_RESTART_DELAY

    if ( wipe ) {

        local outputs = []

        for ( local i = GetNumElements( benchmark_ent, ON_TRIGGER ); i >= 0; i-- ) {

            local t = {}
            GetOutputTable( benchmark_ent, ON_TRIGGER, t, i )
            outputs.append( t )
        }

        foreach ( o in outputs )
            foreach ( _ in o )
                RemoveOutput( benchmark_ent, ON_TRIGGER, o.target, o.input, o.parameter )
    }
    _Print( BENCHMARK_END )
    __active_benchmarks.clear()
}

// alias for _StopAll
Benchmark._Stop <- Benchmark._StopAll

/************************************************************
 * One-off single function call with an optional delay      *
 * WARNING: Cannot be stopped using _StopAll                *
 * Benchmark._Kill( true ) will stop and restart everything *
 ************************************************************/
function Benchmark::_Run( func, delay = Benchmark.FUNCTION_CALL_DELAY ) {

    local func_name = _GetFunc( func, true )
    if ( FILTER_TEXT ) {
        EntFireByHandle( benchmark_ent, CALL_FUNCTION, format( "Filter_%s", func_name ), delay, null, null )
        delay += 0.1
    }
    EntFireByHandle( benchmark_ent, CALL_FUNCTION, func_name, delay, null, null )
}

/***********************************************************
 * Kill and optionally restart the entire benchmark system *
 ***********************************************************/
function Benchmark::_Kill( restart = false ) {

    __restart = restart
    benchmark_ent.AcceptInput( CANCEL_PENDING, null, null, null )
    benchmark_ent.Kill()
}

/**********************
 * INTERNAL FUNCTIONS *
 **********************/

function Benchmark::__EndLoop() {

    _ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )
    _Print( BENCHMARK_END )
}

function Benchmark::__StartLoop() {

    if ( FILTER_TEXT )
        SendToConsole( format( "con_filter_text %s", BENCHMARK_START ) )

    _Print( BENCHMARK_START )
    RemoveOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, END_LOOP )
    RemoveOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, RESTART_LOOP )
    AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, END_LOOP, __loop_delay + 0.1, -1 )
    AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, RESTART_LOOP, __loop_delay + LOOP_RESTART_DELAY, -1 )
    _ConsoleCmd( PERF_COUNTER_CVAR, 0.01 )
    benchmark_ent.AcceptInput( TRIGGER_INPUT, null, null, null )
}

function Benchmark::__RestartLoop() {

    _ConsoleCmd( PERF_COUNTER_CVAR, 0.01 )
    EntFireByHandle( benchmark_ent, TRIGGER_INPUT, null, 0.1, null, null )
    _Print( BENCHMARK_START )
}