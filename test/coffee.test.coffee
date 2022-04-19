# coffee.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {log, LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap} from '@jdeighan/mapper'
import {
	coffeeExprToJS, coffeeCodeToJS, convertCoffee, cleanJS, minifyJS,
	} from '@jdeighan/mapper/coffee'

simple = new UnitTesterNorm()

# ---------------------------------------------------------------------------

(() ->
	class CoffeeTester extends UnitTester

		transformValue: (code) ->
			return coffeeCodeToJS(code)

	tester = new CoffeeTester()

	# ------------------------------------------------------------------------

	tester.equal 28, """
			# --- a comment

			y = x
			""", """
			// --- a comment
			var y;
			y = x;
			"""

	tester.equal 38, """
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
