# StringInput2.test.coffee

import {strict as assert} from 'assert'

import {
	undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {
	debug, debugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {StringInput} from '@jdeighan/string-input'

dir = mydir(`import.meta.url`)
process.env.DIR_MARKDOWN = mkpath(dir, 'markdown')

simple = new UnitTester()

###
	Tests when mapping to non-strings
###

# ---------------------------------------------------------------------------

class GatherTester extends UnitTester

	transformValue: (oInput) ->

		assert oInput instanceof StringInput,
			"oInput should be a StringInput object"
		return oInput.getAll()

tester = new GatherTester()

# ---------------------------------------------------------------------------

(()->

	cmdRE = ///^
			\s*                # skip leading whitespace
			\# ([a-z][a-z_]*)  # command name
			\s*                # skipwhitespace following command
			(.*)               # command arguments
			$///

	class TestInput extends StringInput

		mapLine: (line, level) ->
			lMatches = line.match(cmdRE)
			if lMatches?
				return { cmd: lMatches[1], argstr: lMatches[2] }
			else
				return line

	tester.equal 224, new TestInput("""
			abc
			#if x==y
				def
			#else
				ghi
			"""), [
			['abc', 0],
			[{ cmd: 'if', argstr: 'x==y' }, 0],
			['def', 1],
			[{ cmd: 'else', argstr: '' }, 0],
			['ghi', 1],
			]
	)()

