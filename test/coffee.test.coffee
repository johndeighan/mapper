# coffee.test.coffee

import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {
	brewCoffee, brewExpr, addImports, convertCoffee,
	} from '@jdeighan/string-input/coffee'

root = process.env.dir_root = mydir(`import.meta.url`)
process.env.DIR_DATA = "#{root}/data
process.env.DIR_MARKDOWN = "#{root}/markdown
process.env.DIR_SYMBOLS = root
simple = new UnitTester()

convertCoffee false

# ---------------------------------------------------------------------------

class CoffeeTester extends UnitTester

	transformValue: (text) ->
		[result, lImports] = brewCoffee(text)
		if isEmpty(lImports)
			return result
		else
			return addImports(result, lImports)

tester = new CoffeeTester()

# ---------------------------------------------------------------------------
# NOTE: When not unit testing, there will be a semicolon after 1000

tester.equal 36, """
		x <== a + 1000
		""", """
		`$:`
		x = a + 1000
		"""

tester.equal 43, """
		# --- a comment line

		x <== a + 1000
		""", """
		`$:`
		x = a + 1000
		"""

# ---------------------------------------------------------------------------
# --- test continuation lines

tester.equal 55, """
		x = 23
		y = x
				+ 5
		""", """
		x = 23
		y = x + 5
		"""

# ---------------------------------------------------------------------------
# --- test auto-import of symbols from file '.symbols'

tester.equal 67, """
		x = 23
		log x
		""", """
		import {log} from '@jdeighan/coffee-utils/log'
		x = 23
		log x
		"""

tester.equal 76, """
		# --- a comment

		x <== a + 1000
		""", """
		`$:`
		x = a + 1000
		"""

# ---------------------------------------------------------------------------
# --- test full translation to JavaScript

convertCoffee true

tester.equal 90, """
		x = 23
		""", """
		var x;
		x = 23;
		"""

tester.equal 97, """
		# --- a comment

		<==
			x = a + 1000
			y = a + 100
		""", """
		var x, y;
		$:{
		x = a + 1000;
		y = a + 100;
		}
		"""

tester.equal 111, """
		# --- a comment

		x <== a + 1000
		""", """
		var x;
		$:
		x = a + 1000;
		"""
