// Functions starts at line 250

if ( "Benchmark" in getroottable() )
    return

/**********
 * CONFIG *
 **********/
local config = {

    // sets mat_queue_mode 0 while script is active
    NO_MULTITHREADING  = true

    // default delay in seconds between function calls
    FUNCTION_CALL_DELAY = 0.1

    // default delay in seconds between full benchmark loop restarts
    LOOP_RESTART_DELAY = 5

    // automatically control the perf counter during benchmarks
    AUTO_PERF_COUNTER = true

    // automatically add functions to the benchmark loop in the order they are defined
    // functions must be scoped to Benchmark.  e.g. Benchmark::MyFunc()
    AUTO_ADD_FUNCTIONS = true

    // filter text in the console
    // -1 = filter nothing (not recommended, floods console with _get perf warnings)
    // 0 = only filter _get calls
    // 1 = filter functions, don't print anything else except our perf warnings
    // 2 = filter functions, but print non-filtered text as gray, not recommended if benchmark includes thinks
    FILTER_TEXT = 1

    // minimum perf warning ms, don't set this too low if FILTER_TEXT is not set to 1
    MIN_PERF_WARNING_MS = 0.01

    // functions will not wait for the next benchmark loop after being added
    // you should almost never set this to true, mostly here for testing
    NO_QUEUE = false
}

/*************
 * CONSTANTS *
 *************/

// put this one in root so other scripts can use it
::__ROOT  <- getroottable()

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
local BENCHMARK_START     = "\n\n========= BENCHMARK START ========="
local BENCHMARK_END       = "========== BENCHMARK END =========="

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

// these exist in entity scope by default, ignore them
local function_blacklist = {

    Call                = null
    DispatchPrecache    = null
    DispatchOnPostSpawn = null
    CancelPendingOnKill = null // also this one
}

/*************************************************************
 * BENCHMARK ENTITY                                          *
 * we're not doing the delay and looping logic in vscript to *
 * avoid tripping the perf counter ourselves                 *
 *************************************************************/
local benchmark_ent = SpawnEntityFromTable( "logic_relay", { targetname = "__benchmark" vscripts = " " spawnflags = config.NO_QUEUE ? 2 : 0 })
NetProps.SetPropBool( benchmark_ent, "m_bForcePurgeFixedupStrings", true )

/****************************************
 * all functions must be scoped to this *
 ****************************************/
::Benchmark <- benchmark_ent.GetScriptScope()

foreach ( k, v in config )
    Benchmark[ k ] <- v

// Misc internal variables
Benchmark.__loop_delay      <-  0.0 // delay between loop restarts
Benchmark.__restart_on_kill <- false // reload the benchmark system after it's killed
Benchmark.__internal_funcs  <- {} // track internal functions
Benchmark.__do_restart      <- false // restart loop is active
Benchmark.__perf_warning_ms <- GetConvarFloat( PERF_COUNTER_CVAR )
Benchmark.__mat_queue_mode  <- GetConvarInt( "mat_queue_mode" )
Benchmark.__old_con_filter  <- GetConvarInt( "con_filter_enable" )

local function __titleprint( title, author, extra = "" ) {

    SendToConsole( "developer 0; mat_queue_mode 0; con_filter_enable 0" )

    local length = title.len()
    if ( author.len() > length )
        length = author.len()
    if ( extra.len() > length )
        length = extra.len()
    length += 2

    local start = "\n\n=", end = "=", padding = " "

    for (local i = 0; i <= length; i++) {

        end     += "="
        start   += "="
        padding += " "
    }

    start += "\n= "
    end   += "\n\n"

    local padding_len = padding.len() - 6

    local __pad = @( text, mod = 0 ) padding_len - (text.len() + mod) > 1 ? padding.slice( 0, padding_len - (text.len() + mod) ) : ""
    error( start )
    print( title )
    error( format( "%s =\n= ", __pad( title, -2 ) ) )
    print( "By " )
    error( format( "%s%s", author, __pad( author ) ) )
    if ( extra != "" ) {
        error( format( "=\n=%s", __pad( "", -4 ) ) )
        error( "=\n= " )
        print( format( "%s%s ", extra, __pad( extra ) ) )
    }
    error( format( "=\n%s", end ) )

    SendToConsole( format( "mat_queue_mode %d; con_filter_enable %d", Benchmark.__mat_queue_mode, Benchmark.__old_con_filter ) )
}

__titleprint( "VScript Benchmarking Script", "Braindawg", "https://github.com/potato-tf/vscript-benchmark" )

// error("\n\n==================================================\n= ")
// print("VScript Benchmarking Script")
// error("                    =\n= ")
// print("By ")
// error("Braindawg")
// error("                                   =\n= ")
// print("https://github.com/potato-tf/vscript-benchmark")
// error(" =\n==================================================\n\n")

// Ghetto constructor/destructor logic using table metamethods
// automatically adds functions to the benchmark loop in the order they're defined
Benchmark.setdelegate({

        delay = 0.0

        function _newslot( k, v ) {

            if ( k == "_BenchmarkDestroy" && _BenchmarkDestroy == null )
                _BenchmarkDestroy = v.bindenv( Benchmark )

            Benchmark.rawset( k, v )

            if ( typeof v == FUNCTION_TYPE && !(k in function_blacklist) && !startswith( k, "_Filter_" ) && !startswith( k, "Input" ) ) {

                // fix anonymous function declarations
                if ( v.getinfos().name == null ) {

                    compilestring( format( @"

                        local _%s = Benchmark.%s

                        function Benchmark::%s() { _%s() }

                    ", k, k, k, k ) )()
                }

                local infos = getstackinfos( 2 )

                if ( startswith( k, "_" ) || (infos.func == "main" && infos.src == "benchmark.nut") )
                    Benchmark.__internal_funcs[k] <- v.bindenv( Benchmark )

                if ( k == "_BenchmarkInit" )
                    _BenchmarkInit()

                else if ( Benchmark.AUTO_ADD_FUNCTIONS && getstackinfos( 2 ).func != "__GetFunc" ) {

                    if ( !(k in Benchmark.__internal_funcs) ) {

                        Add( k, delay )
                        delay += Benchmark.FUNCTION_CALL_DELAY
                    }
                }          
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

// make kill inputs cancel active benchmarks
local function CancelPendingOnKill() {

    self.AcceptInput( CANCEL_PENDING, null, null, null )
    return true
}
Benchmark.InputKill <- CancelPendingOnKill
Benchmark.Inputkill <- CancelPendingOnKill
Benchmark.InputKillHierarchy <- CancelPendingOnKill
Benchmark.Inputkillhierarchy <- CancelPendingOnKill

/*************
 * FUNCTIONS *
 ************/

// console command wrapper
function Benchmark::ConsoleCmd( cmd = PERF_COUNTER_CVAR, value = 1.5 ) {

    if ( value == null )
        return GetConvar( cmd )

    if ( !IS_DEDICATED )
        SendToConsole( format( "%s %.8f", cmd, value ) )

    else if ( CONVAR_ON_ALLOWLIST )
        SetConvar( cmd, value )

    else if ( GetConvar( "sv_allow_point_servercommand" ) == "always" )
        SendToServerConsole( format( "%s %.8f", cmd, value ) )
}

// print with formatting
function Benchmark::BenchmarkPrint( str, ... ) {

    local formatted = format( "%s\n", str )

    if (vargv.len() )
        formatted = format.acall([this, formatted].extend(vargv))

    print( formatted )
    if ( IS_DEDICATED )
        ClientPrint( null, 2, formatted )
}

/****************************************
 * Add a function to the benchmark loop *
 * Accepts string or function reference *
 ****************************************/
function Benchmark::Add( func, delay = Benchmark.FUNCTION_CALL_DELAY ) {

    local func_name = __GetFunc( func, true )

    // apparently !self doesn't work in AddOutput
    if ( FILTER_TEXT ) {

        AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, format( "_Filter_%s", func_name ), delay, -1 )
        delay += 0.02
    }

    AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, func_name, delay, -1 )

    if ( delay > __loop_delay )
        __loop_delay = delay
}

/******************************************
 * Run the benchmark loop once, then stop *
 ******************************************/
function Benchmark::StartOnce() {

    if ( FILTER_TEXT > 0 )
        SendToConsole( "con_filter_text BENCHMARK" )

    BenchmarkPrint( BENCHMARK_START )
    if ( AUTO_PERF_COUNTER )
        ConsoleCmd( PERF_COUNTER_CVAR, MIN_PERF_WARNING_MS )

    RemoveOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, END_LOOP )
    AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, END_LOOP, __loop_delay, -1 )
    benchmark_ent.AcceptInput( TRIGGER_INPUT, null, null, null )
}

/**********************************************************
 * Start the benchmark loop.  Stop the loop with StopAll *
 **********************************************************/
function Benchmark::Start() {

    __StartLoop()
}

/************************************************************************************
 * Find all functions in the Benchmark scope/namespace and start the benchmark loop *
 * WARNING: Do not use this while AUTO_ADD_FUNCTIONS is true, duplicates outputs    *
 ************************************************************************************/
function Benchmark::StartAll( delay = Benchmark.FUNCTION_CALL_DELAY ) {

    foreach ( name, func in Benchmark )
        if ( __ValidateFunc( func ) )
            Add( name, delay++ )
    
    __StartLoop()
}

/*****************************************************
 * Stop the benchmark loop                           *
 * wipe = true will clear all queued benchmark calls *
 *****************************************************/
function Benchmark::Stop( wipe = false ) {

    if ( AUTO_PERF_COUNTER )
        ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )

    benchmark_ent.AcceptInput( CANCEL_PENDING, null, null, null )
    __loop_delay = LOOP_RESTART_DELAY

    if ( wipe ) {

        local outputs = __GetAllOutputs( benchmark_ent, ON_TRIGGER )

        foreach ( o in outputs ) 
            RemoveOutput( benchmark_ent, ON_TRIGGER, o.target, o.input, o.parameter )
    }
    if ( FILTER_TEXT )
        SendToConsole( "con_filter_text \"\"" )

    local txt = BENCHMARK_END

    BenchmarkPrint( BENCHMARK_END )
}

// alias for Stop
Benchmark.StopAll <- Benchmark.Stop

/********************************************************************
 * One-off single function call with an optional delay              *
 * WARNING: Cannot be stopped using StopAll                         *
 * Benchmark.KillBenchmark( true ) will stop and restart everything *
 ********************************************************************/
function Benchmark::RunOnce( func, delay = Benchmark.FUNCTION_CALL_DELAY ) {

    local func_name = __GetFunc( func, true )
    if ( FILTER_TEXT ) {
        EntFireByHandle( benchmark_ent, CALL_FUNCTION, format( "_Filter_%s", func_name ), delay, null, null )
        delay += 0.1
    }
    EntFireByHandle( benchmark_ent, CALL_FUNCTION, func_name, delay, null, null )
}

/***********************************************************
 * Kill and optionally restart the entire benchmark system *
 ***********************************************************/
function Benchmark::KillBenchmark( restart = false ) {

    __restart_on_kill = restart
    benchmark_ent.Kill()
}

/**********************
 * INTERNAL FUNCTIONS *
 **********************/
function Benchmark::__EndLoop() {

    if ( FILTER_TEXT > 0 )
        SendToConsole( "con_filter_text BENCHMARK" )

    if ( AUTO_PERF_COUNTER )
        ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )

    local txt = BENCHMARK_END
    if ( __do_restart )
        txt = format( "%s\n\n Restarting in %.2f seconds", BENCHMARK_END, LOOP_RESTART_DELAY )

    EntFireByHandle( benchmark_ent, "RunScriptCode", format( "BenchmarkPrint( @`%s` )", txt ), 0.02, null, null )
}

function Benchmark::__StartLoop() {

    if ( FILTER_TEXT > 0 )
        SendToConsole( "con_filter_text BENCHMARK" )

    if ( !__do_restart )
        BenchmarkPrint( BENCHMARK_START )

    RemoveOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, END_LOOP )
    RemoveOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, RESTART_LOOP )
    AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, END_LOOP, __loop_delay, -1 )
    AddOutput( benchmark_ent, ON_TRIGGER, benchmark_ent.GetName(), CALL_FUNCTION, RESTART_LOOP, __loop_delay + LOOP_RESTART_DELAY, -1 )

    __do_restart = true

    if ( AUTO_PERF_COUNTER )
        ConsoleCmd( PERF_COUNTER_CVAR, MIN_PERF_WARNING_MS )

    benchmark_ent.AcceptInput( TRIGGER_INPUT, null, null, null )
}

function Benchmark::__RestartLoop() {

    if ( FILTER_TEXT > 0 )
        SendToConsole( "con_filter_text BENCHMARK" )

    if ( AUTO_PERF_COUNTER )
        ConsoleCmd( PERF_COUNTER_CVAR, MIN_PERF_WARNING_MS )

    BenchmarkPrint( BENCHMARK_START )
    EntFireByHandle( benchmark_ent, TRIGGER_INPUT, null, 0.03, null, null )
}

function Benchmark::__ValidateFunc( func ) {

    local func_name = typeof func == FUNCTION_TYPE ? func.getinfos().name : func

    return typeof func == FUNCTION_TYPE
        && !( func_name in Benchmark.__internal_funcs )
        && !startswith( func_name, "Input" )
        && !startswith( func_name, "_Filter_" )
        && !( func_name in function_blacklist )
}

/***********************************************************************
 * Get function reference and configure scoping for the benchmark loop *
 * Accepts string or function reference                                *
 * if name_only is true, only the function name will be returned       *
 ***********************************************************************/
function Benchmark::__GetFunc( func, name_only = false ) {

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

    if ( FILTER_TEXT > 0 )
        compilestring(format("function Benchmark::_Filter_%s() { SendToConsole( \"con_filter_text %s\" ) }", func_name, func_name) )()

    return name_only ? func_name : func
}

function Benchmark::__GetAllOutputs( ent, output ) {

	local outputs = array( GetNumElements( ent, output ) )

	foreach ( i, t in outputs ) {
        t = {}
		GetOutputTable( ent, output, t, i )
        outputs[i] = t
	}
	return outputs
}

function Benchmark::_BenchmarkInit() {

    __filename <- getstackinfos( 2 ).src

    if ( !IS_DEDICATED && ( NO_MULTITHREADING || FILTER_TEXT ) && __mat_queue_mode ) {

        ClientPrint( null, 3, MT_MESSAGE )
        ClientPrint( null, 4, MT_MESSAGE )
        SendToConsole( "mat_queue_mode 0" )
    }

    if ( FILTER_TEXT <= 0 ) {

        if ( FILTER_TEXT == -1 ) {

            SendToConsole( "con_filter_text \"\"; con_filter_text_out \"\"; con_filter_enable 0" )
            return
        }

        SendToConsole( "con_filter_text \"\"; con_filter_enable 1" )

        return
    }

    SendToConsole( format("con_filter_text_out _get; con_filter_text BENCHMARK; con_filter_enable %d", FILTER_TEXT.tointeger() ) )
}

function Benchmark::_BenchmarkDestroy() {

    if ( __restart_on_kill )
        EntFire( "BigNet", "RunScriptFile", __filename, 0.2 )

    if ( AUTO_PERF_COUNTER )
        ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )

    if ( FILTER_TEXT )
        SendToConsole( "con_filter_enable 0" )

    if ( "__ROOT" in getroottable() )
        delete ::__ROOT
}