# SmartInput.test.coffee

import assert from 'assert'

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {
	undef, pass, isEmpty, isArray, isString,
	} from '@jdeighan/coffee-utils'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {
	SmartInput, stdSplitCommand, stdIsComment,
	} from '@jdeighan/string-input'
import {addHereDocType} from '@jdeighan/string-input/heredoc'

simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.equal 24, stdIsComment('# ---'), true
simple.equal 25, stdIsComment('#'), true
simple.equal 26, stdIsComment('##'), true
simple.equal 27, stdIsComment('#define X 3'), false
simple.equal 28, stdIsComment('##define X 3'), true

simple.equal 30, stdSplitCommand('#define X 3'), ['define', 'X 3']
simple.equal 30, stdSplitCommand('#define    X  3'), ['define', 'X  3']
simple.equal 30, stdSplitCommand('##define X 3'), undef
simple.equal 30, stdSplitCommand('# define X 3'), undef

# ---------------------------------------------------------------------------

###
	class SmartInput should handle the following:
		- remove empty lines (or override handleEmptyLine())
		- remove comments (or override handleComment())
		- join continue lines (or override getContLines() / joinContLines())
		- handle HEREDOCs (or override getHereDocLines() / heredocStr())
###

# ---------------------------------------------------------------------------

class SmartTester extends UnitTesterNoNorm

	transformValue: (oInput) ->
		if isString(oInput)
			str = oInput
			oInput = new SmartInput(str)
		assert oInput instanceof SmartInput,
			"oInput should be a SmartInput object"
		return oInput.getAllText()

tester = new SmartTester()

# ---------------------------------------------------------------------------
# --- test removing comments and empty lines

tester.equal 57, """
		abc

		# --- a comment
		def
		""", """
		abc
		# --- a comment
		def
		"""

# ---------------------------------------------------------------------------
# --- test overriding handling of comments and empty lines

class CustomInput extends SmartInput

	handleEmptyLine: () ->

		debug "in new handleEmptyLine()"
		return "line #{@lineNum} is empty"

	handleComment: () ->

		debug "in new handleComment()"
		return "line #{@lineNum} is a comment"

tester.equal 83, new CustomInput("""
		abc

		# --- a comment
		def
		"""), """
		abc
		line 2 is empty
		line 3 is a comment
		def
		"""

# ---------------------------------------------------------------------------
# --- test continuation lines

tester.equal 98, """
		h1 color=blue
				This is
				a title

		# --- a comment
		p the end
		""", """
		h1 color=blue This is a title
		# --- a comment
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test trailing backslash

tester.equal 114, """
		h1 color=blue \\
				This is \\
				a title

		# --- a comment
		p the end
		""", """
		h1 color=blue This is a title
		# --- a comment
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test trailing backslash

tester.equal 130, """
		h1 color=blue \\
			This is \\
			a title

		# --- a comment
		p the end
		""", """
		h1 color=blue \\
			This is \\
			a title
		# --- a comment
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC

tester.equal 148, """
		h1 color=<<<
			magenta

		# --- a comment
		p the end
		""", """
		h1 color="magenta"
		# --- a comment
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC with continuation lines

tester.equal 163, """
		h1 color=<<<
				This is a title
			magenta

		# --- a comment
		p the end
		""", """
		h1 color="magenta" This is a title
		# --- a comment
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test using '.' in a HEREDOC

tester.equal 179, """
		h1 color=<<<
			...color
			.
			magenta

		# --- a comment
		p the end
		""", """
		h1 color="color magenta"
		# --- a comment
		p the end
		"""

# ---------------------------------------------------------------------------
#    Test various types of HEREDOC sections
# ---------------------------------------------------------------------------
# --- test empty HEREDOC section

tester.equal 198, """
		h1 name=<<<

		p the end
		""", """
		h1 name=""
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test ending HEREDOC with EOF instead of a blank line

tester.equal 210, """
		h1 name=<<<
		""", """
		h1 name=""
		"""

# ---------------------------------------------------------------------------
# --- test TAML

tester.equal 219, """
		h1 lItems=<<<
			---
			- abc
			- def

		""", """
		h1 lItems=["abc","def"]
		"""

# ---------------------------------------------------------------------------
# --- test one liner

tester.equal 232, """
		error message=<<<
			...an error
			occurred in
			your program

		""", """
		error message="an error occurred in your program"
		"""

# ---------------------------------------------------------------------------
# --- test forcing a literal block

tester.equal 245, """
		TAML looks like: <<<
			===
			---
			- abc
			- def

		""", """
		TAML looks like: "---\\n- abc\\n- def"
		"""

# ---------------------------------------------------------------------------
# --- test ordinary block

tester.equal 259, """
		lRecords = db.fetch(<<<)
			select ID,Name
			from Users

		console.dir lRecords
		""", """
		lRecords = db.fetch("select ID,Name\\nfrom Users")
		console.dir lRecords
		"""

# ---------------------------------------------------------------------------
# --- Test patching file name

tester.equal 273, new SmartInput("""
		in file FILE
		ok
		exiting file FILE
		"""), """
		in file unit test
		ok
		exiting file unit test
		"""


# ---------------------------------------------------------------------------
# --- Test patching line number

tester.equal 287, new SmartInput("""
		on line LINE
		ok
		on line LINE
		"""), """
		on line 1
		ok
		on line 3
		"""
