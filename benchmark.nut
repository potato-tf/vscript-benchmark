::__ROOT  <- getroottable()

if ( "Benchmark" in __ROOT )
    return

/***************************************************
 * CONFIG                                          *
 * most config settings can also be set per-script *
 * e.g. Benchmark.LOOP_RESTART_DELAY = 10          *
 * NO_MULTITHREADING cannot be set per-script      *
 ***************************************************/
local config = {

    NO_MULTITHREADING  = true // sets mat_queue_mode 0 while script is active.  Fixes scrambled console prints.

    FUNCTION_CALL_DELAY = 0.3 // default delay in seconds between function calls
    LOOP_RESTART_DELAY  = 5 // default delay in seconds between full benchmark loop restarts

    AUTO_PERF_COUNTER = true // automatically control the perf counter during benchmarks

    // automatically add functions to the benchmark loop in the order they are defined
    // functions must be scoped to Benchmark.  e.g. Benchmark::MyFunc()
    AUTO_ADD_FUNCTIONS = true

    // filter text in the console
    // -1 = filter nothing (not recommended, floods console with _get perf warnings)
    // 0 = only filter _get calls
    // 1 = filter functions, don't print anything else except our perf warnings
    // 2 = filter functions, but print non-filtered text as gray, not recommended if benchmark includes thinks
    FILTER_TEXT = 1

    // minimum perf warning ms
    // probably don't set this too low if FILTER_TEXT is not 1
    MIN_PERF_WARNING_MS = 0.005

    // log output to file
    // LOG_DIR = "benchmarks" logs to tf/scriptdata/benchmarks/
    LOG_OUTPUT = true
    LOG_DIR    = "benchmarks"

    NO_API     = false // replace API calls with dummy functions for bytecode dumps

    // functions will not wait for the next benchmark loop and will immediately trigger a new benchmark loop
    // you should almost never set this to true, mostly here for testing
    NO_QUEUE = false
}

if ( config.NO_API ) {

    try { dofile( "./no_api_compat.nut", true ) } catch (e) IncludeScript( "no_api_compat" )
    config.AUTO_ADD_FUNCTIONS = false
    config.LOG_OUTPUT = false
}


/*************
 * CONSTANTS *
 *************/
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

local _Filter__Prefix     = "_Filter_"
local Input_Prefix        = "Input"
local con_logfile_str     = "con_logfile"

local IS_DEDICATED        = config.NO_API ? false : IsDedicatedServer()
local CONVAR_ON_ALLOWLIST = config.NO_API ? false : Convars.IsConVarOnAllowList( PERF_COUNTER_CVAR )

// re-define for performance/simplicity
local SetConvar           = config.NO_API ? @( cmd, value ) null : Convars.SetValue.bindenv( Convars )
local GetConvar           = config.NO_API ? @( cmd ) ""  : Convars.GetStr.bindenv( Convars )
local GetConvarInt        = config.NO_API ? @( cmd ) 0   : Convars.GetInt.bindenv( Convars )
local GetConvarFloat      = config.NO_API ? @( cmd ) 0.0 : Convars.GetFloat.bindenv( Convars )

local CreateByClassname   = config.NO_API ? @( classname ) DummyEnt() : Entities.CreateByClassname.bindenv( Entities )
local AddOutput           = config.NO_API ? @( ent, output, target, input, parameter, delay, flags ) null : EntityOutputs.AddOutput.bindenv( EntityOutputs )
local RemoveOutput        = config.NO_API ? @( ent, output, target, input, parameter ) null : EntityOutputs.RemoveOutput.bindenv( EntityOutputs )
local GetNumElements      = config.NO_API ? @( ent, output ) 0 : EntityOutputs.GetNumElements.bindenv( EntityOutputs )
local GetOutputTable      = config.NO_API ? @( ent, output, table, index ) null : EntityOutputs.GetOutputTable.bindenv( EntityOutputs )

// these exist in entity scope by default, or are handled differently, ignore them
local function_blacklist = {

    Call                  = null
    DispatchPrecache      = null
    DispatchOnPostSpawn   = null
    __OpenLogFile         = null
    __CloseLogFile        = null
    __CancelPendingOnKill = null
}

/*************************************************************
 * BENCHMARK ENTITY                                          *
 * we're not doing the delay and looping logic in vscript to *
 * avoid tripping the perf counter ourselves                 *
 *************************************************************/
local benchmark_ent = config.NO_API ? DummyEnt() : SpawnEntityFromTable( "logic_relay", { targetname = "__benchmark" vscripts = " " spawnflags = config.NO_QUEUE ? 2 : 0 })

if ( !config.NO_API )
    NetProps.SetPropBool( benchmark_ent, "m_bForcePurgeFixedupStrings", true )

/****************************************
 * all functions must be scoped to this *
 ****************************************/
::Benchmark <- benchmark_ent.GetScriptScope()

foreach ( k, v in config )
    Benchmark[ k ] <- v

// Misc internal variables
Benchmark.__targetname      <- benchmark_ent.GetName()
Benchmark.__loop_delay      <-  0.0 // delay between loop restarts
Benchmark.__internal_funcs  <- {} // track internal functions
Benchmark.__do_restart      <- false // restart loop is active
Benchmark.__perf_warning_ms <- config.NO_API ? 1.5 : GetConvarFloat( PERF_COUNTER_CVAR )
Benchmark.__mat_queue_mode  <- config.NO_API ? 0 : GetConvarInt( "mat_queue_mode" )
Benchmark.__old_con_filter  <- config.NO_API ? 0 : GetConvarInt( "con_filter_enable" )
Benchmark.__old_logfile     <- config.NO_API ? "" : GetConvar( con_logfile_str )
Benchmark.__num_runs        <- 0

// Ghetto constructor/destructor logic using table metamethods
Benchmark.setdelegate({

        delay = 0.0

        // function _get( k ) {
            // try { 

                // if ( startswith( k, Input_Prefix ) )
                //     return this.rawget( k )

                // local internal = format( "_%s", k )

                // if ( internal in this && internal in __internal_funcs )
                //     return __internal_funcs[ internal ]

            // } catch (e) { @( ... )  }
        // }

        function _newslot( k, v ) {

            if ( k == "__BenchmarkDestroy" && !__BenchmarkDestroy )
                __BenchmarkDestroy = v.bindenv( this )

            this.rawset( k, v )

            if ( typeof v == FUNCTION_TYPE && !(k in function_blacklist) && !startswith( k, _Filter__Prefix ) && !startswith( k, Input_Prefix ) ) {

                // printl(k)
                local call_info = getstackinfos( 2 )

                // fix anonymous function declarations
                if ( v.getinfos().name == null )
                    return compilestring( format( "local _%s = Benchmark.%s.bindenv( Benchmark ); function Benchmark::%s() { _%s() }", k, k, k, k ) )()

                // register internal functions
                if ( k[0] == '_' || (call_info.func == "main" && call_info.src == "benchmark.nut") )
                    this.__internal_funcs[k] <- v.bindenv( Benchmark )

                // fire benchmarkinit
                if ( k == "__BenchmarkInit" )
                    __BenchmarkInit()

                // add function to benchmark loop
                else if ( AUTO_ADD_FUNCTIONS && !(k in __internal_funcs) && call_info.func != "__GetFunc" ) {

                    _Add( k, delay )
                    delay += FUNCTION_CALL_DELAY
                }
            }
        }

    }.setdelegate({

        parent = Benchmark.getdelegate()
        id     = benchmark_ent.GetScriptId()
        __BenchmarkDestroy = null

        function _get( k ) {

            return parent[k]
        }

        function _delslot( k ) {

            if ( k == id ) {
                
                if ( __BenchmarkDestroy )
                    __BenchmarkDestroy()

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
        SendToConsole( format( "%s %s", cmd, value.tostring() ) )

    else if ( CONVAR_ON_ALLOWLIST )
        SetConvar( cmd, value )

    else if ( GetConvar( "sv_allow_point_servercommand" ) == "always" )
        SendToServerConsole( format( "%s %s", cmd, value.tostring() ) )
}

function Benchmark::_ConFilterText( out, str, ... ) {

    local cmd = "con_filter_text"
    cmd += out ? "_out %s;" : " %s;"

    if ( vargv.len() )
        str = format.acall( [this, str+"", "\n"].extend(vargv) )

    SendToConsole( format( cmd, str ) )
}

// print with formatting
function Benchmark::_BenchmarkPrint( str, ... ) {

    local formatted = format( "%s", str+"\n" )

    if (vargv.len() )
        formatted = format.acall([this, formatted].extend(vargv))

    print( formatted )
    if ( IS_DEDICATED )
        ClientPrint( null, 2, formatted )
}


// print with filtering
function Benchmark::_BenchmarkPrintFiltered( str, ... ) {

    if ( vargv.len() )
        str = format.acall( [this, str+"", "\n"].extend(vargv) )

    if ( FILTER_TEXT > 0 )
        // _ConFilterText( false, str, format( "script printf( %s );script ClientPrint( null, 2, %s )", str, str ) )
        _ConFilterText( false, str, format( "script printf( %s ), ClientPrint( null, 2, %s )", str, str ) )

    // print( formatted )
    // if ( IS_DEDICATED )
    //     ClientPrint( null, 2, formatted )
}


/****************************************
 * Add a function to the benchmark loop *
 * Accepts string or function reference *
 ****************************************/
function Benchmark::_Add( func, delay = Benchmark.FUNCTION_CALL_DELAY ) {

    local func_name = __GetFunc( func, true )

    // apparently !self doesn't work in AddOutput
    if ( FILTER_TEXT ) {

        AddOutput( benchmark_ent, ON_TRIGGER, __targetname, CALL_FUNCTION, format( "%s%s", _Filter__Prefix, func_name ), delay, -1 )
        delay += 0.02
    }

    AddOutput( benchmark_ent, ON_TRIGGER, __targetname, CALL_FUNCTION, func_name, delay, -1 )

    if ( delay > __loop_delay )
        __loop_delay = delay
}

/******************************************
 * Run the benchmark loop once, then stop *
 ******************************************/
function Benchmark::_StartOnce() {

    __filename = getstackinfos( 2 ).src

    if ( FILTER_TEXT > 0 )
        SendToConsole( "con_filter_text BENCHMARK" )

    _BenchmarkPrint( BENCHMARK_START )
    if ( AUTO_PERF_COUNTER )
        _ConsoleCmd( PERF_COUNTER_CVAR, MIN_PERF_WARNING_MS )

    RemoveOutput( benchmark_ent, ON_TRIGGER, __targetname, CALL_FUNCTION, END_LOOP )
    AddOutput( benchmark_ent, ON_TRIGGER, __targetname, CALL_FUNCTION, END_LOOP, __loop_delay, -1 )
    benchmark_ent.AcceptInput( TRIGGER_INPUT, null, null, null )
}

/**********************************************************
 * Start the benchmark loop.  Stop the loop with StopAll *
 **********************************************************/
function Benchmark::_Start() {

    __StartLoop()
}

/************************************************************************************
 * Find all functions in the Benchmark scope/namespace and start the benchmark loop *
 * WARNING: Do not use this while AUTO_ADD_FUNCTIONS is true, duplicates outputs    *
 ************************************************************************************/
function Benchmark::_StartAll( delay = Benchmark.FUNCTION_CALL_DELAY ) {

    __filename = getstackinfos( 2 ).src

    foreach ( name, func in Benchmark )
        if ( __ValidateFunc( func ) )
            Add( name, delay++ )
    
    __StartLoop()
}

/*****************************************************
 * Stop the benchmark loop                           *
 * wipe = true will clear all queued benchmark calls *
 *****************************************************/
function Benchmark::_Stop( delay = -1, wipe = false ) {

    if ( AUTO_PERF_COUNTER )
        _ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )

    EntFireByHandle( benchmark_ent, CANCEL_PENDING, null, delay, null, null )
    __loop_delay = LOOP_RESTART_DELAY

    if ( wipe ) {

        local outputs = __GetAllOutputs( benchmark_ent, ON_TRIGGER )

        foreach ( o in outputs ) 
            RemoveOutput( benchmark_ent, ON_TRIGGER, o.target, o.input, o.parameter )
    }
    if ( FILTER_TEXT )
        SendToConsole( "con_filter_text \"\"" )

    local txt = BENCHMARK_END

    _BenchmarkPrint( BENCHMARK_END )
}

// alias for Stop
// Benchmark._StopAll <- Benchmark.Stop

/********************************************************************
 * One-off single function call with an optional delay              *
 * WARNING: Cannot be stopped using StopAll                         *
 ********************************************************************/
function Benchmark::_RunOnce( func, delay = Benchmark.FUNCTION_CALL_DELAY ) {

    local func_name = __GetFunc( func, true )

    __filename = getstackinfos( 2 ).src

    if ( FILTER_TEXT ) {
        EntFireByHandle( benchmark_ent, CALL_FUNCTION, format( "%s%s", _Filter__Prefix, func_name ), delay, null, null )
        delay += 0.1
    }
    if ( LOG_OUTPUT )
        EntFireByHandle( benchmark_ent, "CallScriptFunction", "__OpenLogFile", delay - 0.1, null, null )

    EntFireByHandle( benchmark_ent, CALL_FUNCTION, func_name, delay, null, null )

    if ( LOG_OUTPUT )
        EntFireByHandle( benchmark_ent, "CallScriptFunction", "__CloseLogFile", delay + 0.1, null, null )
}

/**********************
 * INTERNAL FUNCTIONS *
 **********************/

function Benchmark::__EndLoop() {

    __num_runs = 0

    if ( FILTER_TEXT > 0 )
        SendToConsole( "con_filter_text BENCHMARK" )

    if ( AUTO_PERF_COUNTER )
        _ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )

    local txt = BENCHMARK_END
    if ( __do_restart )
        txt = format( "%s\n\n Restarting in %.2f seconds", BENCHMARK_END, LOOP_RESTART_DELAY )

    EntFireByHandle( benchmark_ent, "RunScriptCode", format( "_BenchmarkPrint( @`%s` )", txt ), 0.02, null, null )
}

function Benchmark::__StartLoop() {

    __num_runs = 1

    if ( FILTER_TEXT > 0 )
        SendToConsole( "con_filter_text BENCHMARK" )

    if ( LOG_OUTPUT )
        __OpenLogFile()

    if ( !__do_restart )
        _BenchmarkPrint( BENCHMARK_START )

    RemoveOutput( benchmark_ent, ON_TRIGGER, __targetname, CALL_FUNCTION, END_LOOP )
    RemoveOutput( benchmark_ent, ON_TRIGGER, __targetname, CALL_FUNCTION, RESTART_LOOP )
    AddOutput( benchmark_ent, ON_TRIGGER, __targetname, CALL_FUNCTION, END_LOOP, __loop_delay, -1 )
    AddOutput( benchmark_ent, ON_TRIGGER, __targetname, CALL_FUNCTION, RESTART_LOOP, __loop_delay + LOOP_RESTART_DELAY, -1 )

    __do_restart = true

    if ( AUTO_PERF_COUNTER )
        _ConsoleCmd( PERF_COUNTER_CVAR, MIN_PERF_WARNING_MS )

    benchmark_ent.AcceptInput( TRIGGER_INPUT, null, null, null )
}

function Benchmark::__RestartLoop() {

    __num_runs++

    if ( FILTER_TEXT > 0 )
        SendToConsole( "con_filter_text BENCHMARK" )

    if ( AUTO_PERF_COUNTER )
        _ConsoleCmd( PERF_COUNTER_CVAR, MIN_PERF_WARNING_MS )

    _BenchmarkPrint( BENCHMARK_START )
    EntFireByHandle( benchmark_ent, TRIGGER_INPUT, null, 0.03, null, null )
}

function Benchmark::__ValidateFunc( func ) {

    local func_name = typeof func == FUNCTION_TYPE ? func.getinfos().name : func

    return typeof func == FUNCTION_TYPE
        && !( func_name in Benchmark.__internal_funcs )
        && !startswith( func_name, Input_Prefix )
        && !startswith( func_name, _Filter__Prefix )
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

    local func_name = func.getinfos().name || UniqueString("ANON_FUNC")

    if ( !(func_name in Benchmark) )
        Benchmark[ func_name ] <- func

    if ( FILTER_TEXT > 0 )
        compilestring(format("function Benchmark::%s%s() { SendToConsole( \"con_filter_text %s\" ) }", _Filter__Prefix, func_name, func_name) )()

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

function Benchmark::__CancelPendingOnKill() {

    self.AcceptInput( CANCEL_PENDING, null, null, null )
    return true
}

function Benchmark::__OpenLogFile() {
    
    if ( LOG_OUTPUT ) {

        local time = {}
        LocalTime( time )
        local logfile = format( "scriptdata/%s/%d_%d_%d_%d_%d_%d.log", LOG_DIR, time.year, time.month, time.day, time.hour, time.minute, time.second )
        FileToString( logfile ) // create log file
        _ConsoleCmd( con_logfile_str, logfile )
    }

    return true
}

function Benchmark::__CloseLogFile() {

    if ( LOG_OUTPUT )
        _ConsoleCmd( con_logfile_str, __old_logfile )

    return true
}


function Benchmark::__titleprint( title, author, extra = "" ) {

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

function Benchmark::__BenchmarkInit() {

    SendToConsole( "developer 0; mat_queue_mode 0; con_filter_enable 0" )
    __titleprint( "VScript Benchmarking Script", "Braindawg", "https://github.com/potato-tf/vscript-benchmark" )

    __filename <- getstackinfos( 2 ).src

    if ( !IS_DEDICATED && ( NO_MULTITHREADING || FILTER_TEXT ) && __mat_queue_mode ) {

        ClientPrint( null, 3, MT_MESSAGE )
        ClientPrint( null, 4, MT_MESSAGE )
        SendToConsole( "mat_queue_mode 0" )
    }

    // create log directory
    if ( LOG_OUTPUT )
        FileToString( format( "%s/ ", LOG_DIR ) )

    if ( FILTER_TEXT <= 0 ) {

        SendToConsole( format( "con_filter_text \"\"; %s", FILTER_TEXT == -1 ? "con_filter_text_out \"\"; con_filter_enable 0" : "con_filter_enable 1" ) )
        return
    }
    SendToConsole( format("con_filter_text_out _get; con_filter_text BENCHMARK; con_filter_enable %d", FILTER_TEXT.tointeger() ) )
}

function Benchmark::__BenchmarkDestroy() {

    if ( AUTO_PERF_COUNTER )
        _ConsoleCmd( PERF_COUNTER_CVAR, __perf_warning_ms )

    if ( FILTER_TEXT )
        SendToConsole( "con_filter_enable 0" )

    if ( LOG_OUTPUT )
        _ConsoleCmd( con_logfile_str, __old_logfile )

    if ( "__ROOT" in getroottable() )
        delete ::__ROOT
}

Benchmark.InputKill <- Benchmark.__CancelPendingOnKill
Benchmark.Inputkill <- Benchmark.__CancelPendingOnKill
Benchmark.InputKillHierarchy <- Benchmark.__CancelPendingOnKill
Benchmark.Inputkillhierarchy <- Benchmark.__CancelPendingOnKill

Benchmark.InputCancelPending <- Benchmark.__CloseLogFile
Benchmark.Inputcancelpending <- Benchmark.__CloseLogFile