# preprocess.test.coffee

import {say, undef, setUnitTesting} from '@jdeighan/coffee-utils'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {preprocessCoffee} from '@jdeighan/string-input/convert'

setUnitTesting true
simple = new UnitTester()

# ---------------------------------------------------------------------------

class PreprocessTester extends UnitTester

	transformValue: (text) ->
		return preprocessCoffee(text)

	normalize: (str) -> return str   # disable normalize()

tester = new PreprocessTester()

# ---------------------------------------------------------------------------

tester.equal 23, """
		count = 0
		doubled <== 2 * count
		""", """
		count = 0
		`$: doubled = 2 * count`
		"""

# ---------------------------------------------------------------------------

setUnitTesting false

# ---------------------------------------------------------------------------

tester.equal 37, """
		count = 0
		doubled <== 2 * count
		""", """
		count = 0
		`$: doubled = 2 * count;`
		"""

# ---------------------------------------------------------------------------

tester.equal 47, """
		say "count is 0"
		""", """
		import {say} from '@jdeighan/coffee-utils'
		say "count is 0"
		"""
