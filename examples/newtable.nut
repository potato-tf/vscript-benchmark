// copy/paste this try/catch at the top of the script to initialize everything.
try { if ( !("Benchmark" in getroottable()) ) dofile( "benchmark.nut" ) } catch ( e ) { IncludeScript( "benchmark" ) }

// direct length index lookups instead of .len() calls.
Benchmark.NewTable <- class {

    _tbl   = null // the real table in our class
    length = 0 // length variable, static so other functions can't override it.

    constructor( tbl = null ) {  this._tbl = ( tbl || {} ) ; this.length = this._tbl.len() }

    function get(k) { _tbl[k] }
    function set(k, v) { k in _tbl ? _tbl[k] = v : (length++, _tbl[k] <- v) }
    function del(k) { ( length--, delete _tbl[k] ) }
}

local tab = Benchmark.NewTable()
local _tbl = tab._tbl

// insert stuff into the table and increment the table length
for (local i = 0; i <= 1000; i++)
{
    tab.set("value_" + i, i )
}

// .len() eval
function Benchmark::Len() {
    for (local i = 0; i < 1000; i++)
        print(_tbl.len() == 1000)
}

// index lookup, ~2.5% faster
function Benchmark::Length() {
    for (local i = 0; i < 1000; i++)
        print(tab.length == 1000)
}

Benchmark._Start()