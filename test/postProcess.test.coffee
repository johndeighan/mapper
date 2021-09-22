# postProcess.test.coffee

import {
	undef, isEmpty,
	} from '@jdeighan/coffee-utils'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {StringInput} from '@jdeighan/string-input'
import {
	postProcessCoffee, getNeededImports,
	} from '@jdeighan/string-input/coffee'

simple = new UnitTester()

# ---------------------------------------------------------------------------

class PostProcessTester extends UnitTester

	transformValue: (code) ->

		return postProcessCoffee(code)

	# --- disable normalize() to check for proper indentation
	normalize: (str) -> return str

tester = new PostProcessTester()

# ---------------------------------------------------------------------------

tester.equal 30, """
		$:{;
		var x, y;
		x = a + 1000;
		y = a + 100;
		};
		""", """
		var x, y;
		$:{
		x = a + 1000;
		y = a + 100;
		}
		"""

# ---------------------------------------------------------------------------

tester.equal 46, """
		$:;
		var x;
		x = a + 1000;
		""", """
		var x;
		$:
		x = a + 1000;
		"""

# ---------------------------------------------------------------------------
