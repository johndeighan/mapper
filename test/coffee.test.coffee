# coffee.test.coffee

import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {hEnvLib} from '@jdeighan/coffee-utils/envlib'
import {
	brewCoffee, brewExpr, convertCoffee,
	} from '@jdeighan/string-input/coffee'

root = hEnvLib.DIR_ROOT = mydir(`import.meta.url`)
hEnvLib.DIR_DATA = "#{root}/data
hEnvLib.DIR_MARKDOWN = "#{root}/markdown
hEnvLib.DIR_SYMBOLS = root
simple = new UnitTester()

convertCoffee false

# ---------------------------------------------------------------------------

class CoffeeTester extends UnitTester

	transformValue: (code) ->
		newcode = brewCoffee(code)
		return newcode

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
		logger x
		""", """
		import {log as logger} from '@jdeighan/coffee-utils/log'
		x = 23
		logger x
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
