# coffee.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {log, LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap} from '@jdeighan/mapper'
import {
	CoffeePreProcessor,
	coffeeExprToJS, coffeeCodeToJS, cleanJS, minifyJS,
	} from '@jdeighan/mapper/coffee'

# ---------------------------------------------------------------------------
# --- Test the CoffeePreProcessor
#        1. retain comments
#        2. remove blank lines
#        3. replace $<ident> with #{OL(<ident>)}

(() ->
	class PreProcessTester extends UnitTester

		transformValue: (code) ->
			return doMap(CoffeePreProcessor, import.meta.url, code)

	tester = new PreProcessTester()

	# ------------------------------------------------------------------------

	tester.equal 31, """
			# --- a comment

			y = x
			""", """
			# --- a comment
			y = x
			"""

	tester.equal 40, """
			LOG "x is $x"
			""", """
			LOG "x is \#{OL(x)}"
			"""

	tester.equal 46, """
			x = 3
			debug "word is $word, not $this"
			""", """
			x = 3
			debug "word is \#{OL(word)}, not \#{OL(this)}"
			"""

	)()

# ---------------------------------------------------------------------------

(() ->
	class CoffeeTester extends UnitTester

		transformValue: (code) ->
			return coffeeCodeToJS(code)

	tester = new CoffeeTester()

	# ------------------------------------------------------------------------

	tester.equal 68, """
			# --- a comment

			y = x
			""", """
			// --- a comment
			var y;
			y = x;
			"""

	tester.equal 78, """
			# --- a comment

			x = 3
			callme 'a', 3, [1,2,3]
			y = if x==3 then 'OK' else 'Bad'
			""", """
			// --- a comment
			var x, y;
			x = 3;
			callme('a', 3, [1, 2, 3]);
			y = x === 3 ? 'OK' : 'Bad';
			"""

	)()

# ---------------------------------------------------------------------------
