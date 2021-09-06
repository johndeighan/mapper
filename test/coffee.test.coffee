# coffee.test.coffee

import {say, undef, setUnitTesting} from '@jdeighan/coffee-utils'
import {startDebugging, endDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {brewCoffee, brewExpr} from '@jdeighan/string-input/convert'

root = process.env.dir_root = mydir(`import.meta.url`)
process.env.dir_data = "#{root}/data
process.env.dir_markdown = "#{root}/markdown
simple = new UnitTester()
setUnitTesting(true)

# ---------------------------------------------------------------------------

class CoffeeTester extends UnitTester

	transformValue: (text) ->
		result = brewCoffee(text)
		return result

tester = new CoffeeTester()

# ---------------------------------------------------------------------------
# NOTE: When not unit testing, there will be a semicolon after 1000

tester.equal 27, """
		x <== a + 1000
		""", """
		`$: x = a + 1000`
		"""

tester.equal 33, """
		# --- a comment line

		x <== a + 1000
		""", """
		`$: x = a + 1000`
		"""

# ---------------------------------------------------------------------------
# --- test auto-import of symbols from file '.symbols'

tester.equal 44, """
		x = 23
		say x
		""", """
		import {say} from '@jdeighan/coffee-utils'
		x = 23
		say x
		"""

# ---------------------------------------------------------------------------
# --- test full translation to JavaScript

setUnitTesting false

tester.equal 58, """
		x = 23
		""", """
		var x;
		x = 23;
		"""

tester.equal 65, """
		# --- a comment

		x <== a + 1000
		""", """
		$: x = a + 1000;;
		"""
setUnitTesting true
