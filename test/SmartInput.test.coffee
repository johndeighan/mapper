# SmartInput.test.coffee

import {strict as assert} from 'assert'

import {
	undef, pass, isEmpty,
	setUnitTesting, unitTesting,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {SmartInput} from '@jdeighan/string-input'

dir = mydir(`import.meta.url`)
process.env.DIR_MARKDOWN = mkpath(dir, 'markdown')

simple = new UnitTester()
setUnitTesting true

###
	class SmartInput should handle the following:
		- remove empty lines (or override handleEmptyLine())
		- remove comments (or override handleComment())
		- join continue lines (or override getContLines() / joinContLines())
		- handle HEREDOCs (or override getHereDocLines() / heredocStr())
###

# ---------------------------------------------------------------------------

class GatherTester extends UnitTester

	transformValue: (oInput) ->
		assert oInput instanceof SmartInput,
			"oInput should be a SmartInput object"
		return oInput.getAll()

tester = new GatherTester()

# ---------------------------------------------------------------------------
# --- test removing comments and empty lines

tester.equal 48, new SmartInput("""
		abc

		# --- a comment
		def
		"""), [
		'abc',
		'def',
		]

# ---------------------------------------------------------------------------
# --- test overriding handling of comments and empty lines

class CustomInput extends SmartInput

	handleEmptyLine: () ->

		debug "in new handleEmptyLine()"
		return "line #{@lineNum} is empty"

	handleComment: () ->

		debug "in new handleComment()"
		return "line #{@lineNum} is a comment"

tester.equal 73, new CustomInput("""
		abc

		# --- a comment
		def
		"""), [
		'abc',
		'line 2 is empty',
		'line 3 is a comment',
		'def',
		]

# ---------------------------------------------------------------------------
# --- test continuation lines

tester.equal 88, new SmartInput("""
		h1 color=blue
				This is
				a title

		# --- a comment
		p the end
		"""), [
		'h1 color=blue This is a title',
		'p the end',
		]

# ---------------------------------------------------------------------------
# --- test HEREDOC

tester.equal 103, new SmartInput("""
		h1 color="<<<"
			magenta

		# --- a comment
		p the end
		"""), [
		'h1 color="magenta"',
		'p the end',
		]

# ---------------------------------------------------------------------------
# --- test HEREDOC with continuation lines

tester.equal 103, new SmartInput("""
		h1 color="<<<"
				This is a title
			magenta

		# --- a comment
		p the end
		"""), [
		'h1 color="magenta" This is a title',
		'p the end',
		]

# ---------------------------------------------------------------------------
# --- test using '.' in a HEREDOC

tester.equal 103, new SmartInput("""
		h1 color="<<<"
			color
			.
			magenta

		# --- a comment
		p the end
		"""), [
		'h1 color="color  magenta"',
		'p the end',
		]
