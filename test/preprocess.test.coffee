# preProcess.test.coffee

import {
	undef, arrayToString, isEmpty,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {
	preProcessCoffee, getNeededImports,
	} from '@jdeighan/string-input/coffee'


simple = new UnitTester()

# ---------------------------------------------------------------------------

class PreprocessTester extends UnitTester

	transformValue: (text) ->
		return preProcessCoffee(text)

	normalize: (str) -> return str   # disable normalize()

tester = new PreprocessTester()

###
	preProcessCoffee() should handle:
		remove empty lines
		remove comments
		continuation lines
		HEREDOCs
		<var> <== <expr>
		<==
			<block>
###
# ---------------------------------------------------------------------------

tester.equal 39, """

		# comment
		count
				= 0

		meaning = 42
		""", """
		count = 0
		meaning = 42
		"""

# ---------------------------------------------------------------------------

tester.equal 53, """

		# comment
		hData = <<<
			---
			a: 1
			b:
				- abc
				- def

		""", """
		hData = {"a":1,"b":["abc","def"]}
		"""

# ---------------------------------------------------------------------------

tester.equal 31, """
		count = 0
		doubled <== 2 * count
		""", """
		count = 0
		`$:`
		doubled = 2 * count
		"""

# ---------------------------------------------------------------------------

tester.equal 46, """
		count = 0
		doubled <== 2 * count
		""", """
		count = 0
		`$:`
		doubled = 2 * count
		"""

# ---------------------------------------------------------------------------

tester.equal 57, """
		count = 0
		<==
			console.log 2 * count
		""", """
		count = 0
		`$:{`
		console.log 2 * count
		`}`
		"""

# ---------------------------------------------------------------------------

tester.equal 71, """
		log "count is 0"
		""", """
		log "count is 0"
		"""
