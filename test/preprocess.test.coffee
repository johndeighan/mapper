# preProcess.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {
	undef, isEmpty,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {preProcessCoffee} from '@jdeighan/string-input/coffee'

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

tester.equal 35, """

		# comment
		count
				= 0

		meaning = 42
		""", """
		count = 0
		meaning = 42
		"""

# ---------------------------------------------------------------------------

tester.equal 49, """

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

tester.equal 65, """
		count = 0
		doubled <== 2 * count
		""", """
		count = 0
		`$:{`
		doubled = 2 * count
		`}`
		"""

# ---------------------------------------------------------------------------

tester.equal 77, """
		count = 0
		doubled <== 2 * count
		""", """
		count = 0
		`$:{`
		doubled = 2 * count
		`}`
		"""

# ---------------------------------------------------------------------------

tester.equal 89, """
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

tester.equal 102, """
		log "count is 0"
		""", """
		log "count is 0"
		"""
