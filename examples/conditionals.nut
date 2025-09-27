// copy/paste this try/catch for your benchmarks if you want vanilla squirrel support
try { 
    if ( !("Benchmark" in getroottable()) ) 
        dofile( "benchmark.nut" ) 
} 
catch ( e ) { 
    IncludeScript( "benchmark" ) 
}

Benchmark.LOOP_RESTART_DELAY <- 1.0

/************************************************************************************************************************************
 * CONDITIONAL TESTING:                                                                                                             *
 * Squirrel's bytecode compiler is not smart enough to replace conditionals in boolean expressions with simple _OP_JZ instructions. *
 * Instead, it will always output _OP_AND or _OP_OR, which assign an extra variable to the stack.                                   *
 * This means if/else chains are slightly faster to short circuit, as they skip this stack assignment.                              *
 * More if/else chains means more bytecode, so && and || are still faster when the condition passes.                                *
 * Difference is ~5-15%                                                                                                             *
 ************************************************************************************************************************************/

local a = 1, b = 2, c = 3
blah <- true
test <- false

function Benchmark::ConditionalShortCircuit_OR() {

    test = false

    for (local i = 0; i < 100000; i++) {

        if ( a == 1 || b == 2 || c == 3 )
            test <- true

        blah <- test

    }
}

// ~5-15% faster to short circuit
function Benchmark::IfElseShortCircuit_OR() {

    test = false

    for (local i = 0; i < 100000; i++) {

        if ( a == 1 )
            test <- true
        else if ( b == 2 )
            test <- true
        else if ( c == 3 )
            test <- true

        blah <- test

    }
}

function Benchmark::IfElseTestAll_OR() {

    test = false

    for (local i = 0; i < 100000; i++) {

        if ( a == 0 )
            test <- true
        else if ( b == 0 )
            test <- true
        else if ( c == 0 )
            test <- true

        blah <- test

    }
}

// ~5-15% faster to test all
function Benchmark::ConditionalTestAll_OR() {

    test = false

    for (local i = 0; i < 100000; i++) {

        if ( a == 0 || b == 0 || c == 0 )
            test <- true

        blah <- test

    }
}

Benchmark._Start()