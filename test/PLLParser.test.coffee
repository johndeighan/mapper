# PLLParser.test.coffee

import assert from 'assert'

import {UnitTester} from '@jdeighan/unit-tester'
import {
	undef, error, warn, croak,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {PLLParser} from '@jdeighan/mapper/pll'

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

tester.equal 31, new PLLParser("""
		line 1
		line 2
			line 3
		"""), [
		[0, 1, 'line 1']
		[0, 2, 'line 2']
		[1, 3, 'line 3']
		]

# ---------------------------------------------------------------------------

tester.equal 43, new PLLParser("""
		line 1
			line 2
				line 3
		"""), [
		[0, 1, 'line 1']
		[1, 2, 'line 2']
		[2, 3, 'line 3']
		]

# ---------------------------------------------------------------------------
# Test extending PLLParser

(() ->
	class EnvParser extends PLLParser

		mapNode: (line) ->

			if (lMatches = line.match(///^
					\s*
					([A-Za-z]+)
					\s*
					=
					\s*
					([A-Za-z0-9]+)
					\s*
					$///))
				[_, left, right] = lMatches
				return [left, right]
			else
				croak "Bad line in EnvParser"

	parser = new EnvParser("""
			name = John
				last = Deighan
			age = 68
			town = Blacksburg
			""")

	tree = parser.getTree()

	simple.equal 84, tree, [
		{ lineNum: 1, node: ['name','John'], body: [
			{ lineNum: 2, node: ['last','Deighan'] }
			]}
		{ lineNum: 3, node: ['age','68'] },
		{ lineNum: 4, node: ['town','Blacksburg'] },
		]

	)()

# ---------------------------------------------------------------------------
# Test extending PLLParser when mapNode() sometimes returns undef

(() ->
	class EnvParser extends PLLParser

		mapNode: (line) ->

			if (lMatches = line.match(///^
					\s*
					([A-Za-z]+)
					\s*
					=
					\s*
					([A-Za-z0-9]+)
					\s*
					$///))
				[_, left, right] = lMatches
				if (left == 'name')
					return undef
				return right
			else
				croak "Bad line in EnvParser"

	parser = new EnvParser("""
			name = John
				last = Deighan
			age = 68
			town = Blacksburg
			""")

	tree = parser.getTree()

	simple.equal 127, tree, [
		{ lineNum: 3, node: '68' },
		{ lineNum: 4, node: 'Blacksburg' },
		]

	)()
