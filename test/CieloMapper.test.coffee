# CieloMapper.test.coffee

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
	CieloMapper, stdSplitCommand, stdIsComment,
	} from '@jdeighan/mapper'
import {addHereDocType} from '@jdeighan/mapper/heredoc'
import {FuncHereDoc} from '@jdeighan/mapper/func'
import {TAMLHereDoc} from '@jdeighan/mapper/taml'

addHereDocType new FuncHereDoc()
addHereDocType new TAMLHereDoc()
simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.equal 29, stdIsComment('# ---'), true
simple.equal 30, stdIsComment('#'), true
simple.equal 31, stdIsComment('##'), true
simple.equal 32, stdIsComment('#define X 3'), false
simple.equal 33, stdIsComment('##define X 3'), true

simple.equal 35, stdSplitCommand('#define X 3'), ['define', 'X 3']
simple.equal 36, stdSplitCommand('#define    X  3'), ['define', 'X  3']
simple.equal 37, stdSplitCommand('##define X 3'), undef
simple.equal 38, stdSplitCommand('# define X 3'), undef

# ---------------------------------------------------------------------------

###
	class CieloMapper should handle the following:
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
			oInput = new CieloMapper(str)
		assert oInput instanceof CieloMapper,
			"oInput should be a CieloMapper object"
		return oInput.getBlock()

tester = new SmartTester()

# ---------------------------------------------------------------------------
# --- test removing comments and empty lines

tester.equal 67, """
		abc

		# --- a comment
		def
		""", """
		abc
		# --- a comment
		def
		"""

# ---------------------------------------------------------------------------
# --- test continuation lines

tester.equal 81, """
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

tester.equal 97, """
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

tester.equal 113, """
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

tester.equal 131, """
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

tester.equal 146, """
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

tester.equal 162, """
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

tester.equal 181, """
		h1 name=<<<

		p the end
		""", """
		h1 name=""
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test ending HEREDOC with EOF instead of a blank line

tester.equal 193, """
		h1 name=<<<
		""", """
		h1 name=""
		"""

# ---------------------------------------------------------------------------
# --- test TAML

tester.equal 202, """
		h1 lItems=<<<
			---
			- abc
			- def

		""", """
		h1 lItems=["abc","def"]
		"""

# ---------------------------------------------------------------------------
# --- test one liner

tester.equal 215, """
		error message=<<<
			...an error
			occurred in
			your program

		""", """
		error message="an error occurred in your program"
		"""

# ---------------------------------------------------------------------------
# --- test forcing a literal block

tester.equal 228, """
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

tester.equal 242, """
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

tester.equal 256, """
		in file __FILE__
		ok
		exiting file __FILE__
		""", """
		in file unit test
		ok
		exiting file unit test
		"""


# ---------------------------------------------------------------------------
# --- Test patching line number

tester.equal 270, """
		on line __LINE__
		ok
		on line __LINE__
		""", """
		on line 1
		ok
		on line 3
		"""

# ---------------------------------------------------------------------------
# --- Test #define and replacement strings

tester.equal 283, """
		abc
		#define X 42
		var y = __X__
		""", """
		abc
		var y = 42
		"""

# ---------------------------------------------------------------------------
# --- test overriding handling of comments and empty lines

class CustomInput extends CieloMapper

	handleEmptyLine: () ->

		debug "in new handleEmptyLine()"
		return "line #{@lineNum} is empty"

	handleComment: () ->

		debug "in new handleComment()"
		return "line #{@lineNum} is a comment"

tester.equal 307, new CustomInput("""
		abc

		# --- a comment
		def
		"""), """
		abc
		line 2 is empty
		line 3 is a comment
		def
		"""
