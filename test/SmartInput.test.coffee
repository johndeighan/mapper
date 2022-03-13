# SmartInput.test.coffee

import assert from 'assert'

import {UnitTester} from '@jdeighan/unit-tester'
import {
	undef, pass, isEmpty, isArray, isString, CWS,
	} from '@jdeighan/coffee-utils'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {SmartInput} from '@jdeighan/string-input'
import {addHereDocType, BaseHereDoc} from '@jdeighan/string-input/heredoc'

dir = mydir(`import.meta.url`)
process.env.DIR_MARKDOWN = mkpath(dir, 'markdown')
process.env.DIR_DATA = mkpath(dir, 'data')

simple = new UnitTester()

###
	class SmartInput should handle the following:
		- remove empty lines (or override handleEmptyLine())
		- remove comments (or override handleComment())
		- join continue lines (or override getContLines() / joinContLines())
		- handle HEREDOCs (or override getHereDocLines() / heredocStr())
###

# ---------------------------------------------------------------------------

class SmartTester extends UnitTester

	normalize: (str) ->
		return str

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

tester.equal 52, """
		abc

		# --- a comment
		def
		""", """
		abc
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

tester.equal 77, new CustomInput("""
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

tester.equal 92, """
		h1 color=blue
				This is
				a title

		# --- a comment
		p the end
		""", """
		h1 color=blue This is a title
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test trailing backslash

tester.equal 107, """
		h1 color=blue \\
				This is \\
				a title

		# --- a comment
		p the end
		""", """
		h1 color=blue This is a title
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test trailing backslash

tester.equal 122, """
		h1 color=blue \\
			This is \\
			a title

		# --- a comment
		p the end
		""", """
		h1 color=blue \\
			This is \\
			a title
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC

tester.equal 139, """
		h1 color=<<<
			magenta

		# --- a comment
		p the end
		""", """
		h1 color="magenta"
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC with continuation lines

tester.equal 153, """
		h1 color=<<<
				This is a title
			magenta

		# --- a comment
		p the end
		""", """
		h1 color="magenta" This is a title
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test using '.' in a HEREDOC

tester.equal 168, """
		h1 color=<<<
			...color
			.
			magenta

		# --- a comment
		p the end
		""", """
		h1 color="color magenta"
		p the end
		"""

# ---------------------------------------------------------------------------
#    Test various types of HEREDOC sections
# ---------------------------------------------------------------------------
# --- test empty HEREDOC section

tester.equal 186, """
		h1 name=<<<

		# --- a comment
		p the end
		""", """
		h1 name=""
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test ending HEREDOC with EOF instead of a blank line

tester.equal 199, """
		h1 name=<<<
		""", """
		h1 name=""
		"""

# ---------------------------------------------------------------------------
# --- test TAML

tester.equal 208, """
		h1 lItems=<<<
			---
			- abc
			- def

		""", """
		h1 lItems=["abc","def"]
		"""

# ---------------------------------------------------------------------------
# --- test one liner

tester.equal 221, """
		error message=<<<
			...an error
			occurred in
			your program

		""", """
		error message="an error occurred in your program"
		"""

# ---------------------------------------------------------------------------
# --- test forcing a literal block

tester.equal 234, """
		TAML looks like: <<<
			===
			---
			- abc
			- def

		""", """
		TAML looks like: "---\\n- abc\\n- def"
		"""

# ---------------------------------------------------------------------------
# --- test anonymous functions

tester.equal 248, """
		input on:click={<<<}
			(event) ->
				console.log('click')

		""", """
		input on:click={(event) ->
			console.log('click')}
		"""

# ---------------------------------------------------------------------------
# --- test anonymous functions, again

tester.equal 260, """
		input on:click={<<<}
			(event) ->
				callme(x)
				console.log('click')

		""", """
		input on:click={(event) ->
			callme(x)
			console.log('click')}
		"""

# ---------------------------------------------------------------------------
# --- test ordinary block

tester.equal 272, """
		lRecords = db.fetch(<<<)
			select ID,Name
			from Users

		console.dir(lRecords);
		""", """
		lRecords = db.fetch("select ID,Name\\nfrom Users")
		console.dir(lRecords);
		"""

# ---------------------------------------------------------------------------
# --- test creating a custom HEREDOC section
#
#     e.g. with header line *** we'll create an upper-cased single line string

class UCHereDoc extends BaseHereDoc

	map: (block) ->
		block = CWS(remainingLines(block).toUpperCase())
		return super block

addHereDocType(new UCHereDoc())

tester.equal 296, """
		str = <<<
			***
			select ID,Name
			from Users

		""", """
		str = "SELECT ID,NAME FROM USERS"
		"""
