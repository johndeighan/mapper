# PLLParser.test.coffee

import {strict as assert} from 'assert'

import {
	undef, error, warn,
	} from '@jdeighan/coffee-utils'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {PLLParser} from '@jdeighan/string-input'

simple = new UnitTester()

# ---------------------------------------------------------------------------

class GatherTester extends UnitTester

	transformValue: (oInput) ->
		assert oInput instanceof PLLParser,
			"oInput should be a PLLParser object"
		return oInput.getAll()

	normalize: (str) ->
		return str

tester = new GatherTester()

# ---------------------------------------------------------------------------

tester.equal 30, new PLLParser("""
		line 1
		line 2
			line 3
		"""), [
		[0, 1, 'line 1']
		[0, 2, 'line 2']
		[1, 3, 'line 3']
		]

# ---------------------------------------------------------------------------

tester.equal 30, new PLLParser("""
		line 1
			line 2
				line 3
		"""), [
		[0, 1, 'line 1']
		[1, 2, 'line 2']
		[2, 3, 'line 3']
		]
