# preProcess.test.coffee

import {
	log, undef, setUnitTesting, arrayToString, isEmpty,
	} from '@jdeighan/coffee-utils'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {preProcessCoffee} from '@jdeighan/string-input/convert'
import {getNeededImports} from '@jdeighan/string-input/code'

setUnitTesting true
simple = new UnitTester()

# ---------------------------------------------------------------------------

class PreprocessTester extends UnitTester

	transformValue: (text) ->
		newtext = preProcessCoffee(text)
		lImports = getNeededImports(newtext)
		if isEmpty(lImports)
			return newtext
		else
			return arrayToString(lImports) + "\n" + newtext

	normalize: (str) -> return str   # disable normalize()

tester = new PreprocessTester()

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

setUnitTesting false

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
		import {log} from '@jdeighan/coffee-utils'
		log "count is 0"
		"""
