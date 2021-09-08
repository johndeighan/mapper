# coffee.test.coffee

import {
	log, undef, isEmpty, nonEmpty, setUnitTesting,
	} from '@jdeighan/coffee-utils'
import {startDebugging, endDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {brewCoffee, brewExpr} from '@jdeighan/string-input/convert'
import {prependImports} from '@jdeighan/string-input/code'

root = process.env.dir_root = mydir(`import.meta.url`)
process.env.dir_data = "#{root}/data
process.env.dir_markdown = "#{root}/markdown
simple = new UnitTester()
setUnitTesting(true)

# ---------------------------------------------------------------------------

class CoffeeTester extends UnitTester

	transformValue: (text) ->
		[result, lImports] = brewCoffee(text)
		if isEmpty(lImports)
			return result
		else
			return prependImports(result, lImports)

tester = new CoffeeTester()

# ---------------------------------------------------------------------------
# NOTE: When not unit testing, there will be a semicolon after 1000

tester.equal 34, """
		x <== a + 1000
		""", """
		`$:`
		x = a + 1000
		"""

tester.equal 41, """
		# --- a comment line

		x <== a + 1000
		""", """
		`$:`
		x = a + 1000
		"""

# ---------------------------------------------------------------------------
# --- test auto-import of symbols from file '.symbols'

tester.equal 53, """
		x = 23
		log x
		""", """
		import {log} from '@jdeighan/coffee-utils'
		x = 23
		log x
		"""

tester.equal 62, """
		# --- a comment

		x <== a + 1000
		""", """
		`$:`
		x = a + 1000
		"""

# ---------------------------------------------------------------------------
# --- test full translation to JavaScript

setUnitTesting false

tester.equal 76, """
		x = 23
		""", """
		var x;
		x = 23;
		"""

tester.equal 83, """
		# --- a comment

		<==
			x = a + 1000
			y = a + 100
		""", """
		var x, y;
		$:{
		x = a + 1000;
		y = a + 100;
		};
		"""

tester.equal 93, """
		# --- a comment

		x <== a + 1000
		""", """
		var x;
		$:
		x = a + 1000;
		"""
setUnitTesting true
