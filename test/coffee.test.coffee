# coffee.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	brewCoffeeStr, brewExpr, convertCoffee,
	} from '@jdeighan/string-input/coffee'

rootDir = process.env.DIR_ROOT = mydir(`import.meta.url`)
process.env.DIR_DATA = mkpath(rootDir, 'data')
process.env.DIR_MARKDOWN = mkpath(rootDir, 'markdown')
simple = new UnitTester()

convertCoffee false

# ---------------------------------------------------------------------------

class CoffeeTester extends UnitTester

	transformValue: (code) ->
		newcode = brewCoffeeStr(code)
		return newcode

tester = new CoffeeTester()

# ---------------------------------------------------------------------------
# NOTE: When not unit testing, there will be a semicolon after 1000

tester.equal 33, """
		x <== a + 1000
		""", """
		`$:{`
		x = a + 1000
		`}`
		"""

tester.equal 40, """
		# --- a comment line

		x <== a + 1000
		""", """
		`$:{`
		x = a + 1000
		`}`
		"""

# ---------------------------------------------------------------------------
# --- test continuation lines

tester.equal 52, """
		x = 23
		y = x
				+ 5
		""", """
		x = 23
		y = x + 5
		"""

# ---------------------------------------------------------------------------
# --- test use of backslash continuation lines

tester.equal 64, """
		x = 23
		y = x \
		+ 5
		""", """
		x = 23
		y = x \
		+ 5
		"""

# ---------------------------------------------------------------------------
# --- test auto-import of symbols from file '.symbols'

tester.equal 77, """
		x = 23
		logger x
		""", """
		import {log as logger} from '@jdeighan/coffee-utils/log'
		x = 23
		logger x
		"""

tester.equal 86, """
		# --- a comment

		x <== a + 1000
		""", """
		`$:{`
		x = a + 1000
		`}`
		"""

# ---------------------------------------------------------------------------
# --- test full translation to JavaScript

convertCoffee true

tester.equal 100, """
		x = 23
		""", """
		var x;
		x = 23;
		"""

tester.equal 107, """
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

tester.equal 121, """
		# --- a comment

		x <== a + 1000
		""", """
		var x;
		$:{
		x = a + 1000;
		}
		"""
