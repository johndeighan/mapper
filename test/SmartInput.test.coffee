# SmartInput.test.coffee

import {strict as assert} from 'assert'

import {
	undef, pass, isEmpty, isArray,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {hPrivEnv} from '@jdeighan/coffee-utils/privenv'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {SmartInput} from '@jdeighan/string-input'

dir = mydir(`import.meta.url`)
hPrivEnv.DIR_MARKDOWN = mkpath(dir, 'markdown')
hPrivEnv.DIR_DATA = mkpath(dir, 'data')

simple = new UnitTester()

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
		return oInput.getAllText()

tester = new GatherTester()

# ---------------------------------------------------------------------------
# --- test removing comments and empty lines

tester.equal 44, new SmartInput("""
		abc

		# --- a comment
		def
		"""), """
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

tester.equal 69, new CustomInput("""
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

tester.equal 84, new SmartInput("""
		h1 color=blue
				This is
				a title

		# --- a comment
		p the end
		"""), """
		h1 color=blue This is a title
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC

tester.equal 99, new SmartInput("""
		h1 color="<<<"
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="magenta"
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC with continuation lines

tester.equal 113, new SmartInput("""
		h1 color="<<<"
				This is a title
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="magenta" This is a title
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test using '.' in a HEREDOC

tester.equal 128, new SmartInput("""
		h1 color="<<<"
			$$$
			color
			.
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="color magenta"
		p the end
		"""

# ---------------------------------------------------------------------------
#    Test various types of HEREDOC sections
# ---------------------------------------------------------------------------
# --- test empty HEREDOC section

tester.equal 147, new SmartInput("""
		h1 name="<<<"

		# --- a comment
		p the end
		"""), """
		h1 name=""
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test ending HEREDOC with EOF instead of a blank line

tester.equal 160, new SmartInput("""
		h1 name="<<<"
		"""), """
		h1 name=""
		"""

# ---------------------------------------------------------------------------
# --- test TAML

tester.equal 169, new SmartInput("""
		h1 lItems=<<<
			---
			- abc
			- def

		"""), """
		h1 lItems=["abc","def"]
		"""

# ---------------------------------------------------------------------------
# --- test one liner

tester.equal 169, new SmartInput("""
		error message='<<<'
			$$$
			an error
			occurred in
			your program

		"""), """
		error message='an error occurred in your program'
		"""

# ---------------------------------------------------------------------------
# --- test forcing a literal block

tester.equal 196, new SmartInput("""
		TAML looks like: <<<
			!!!
			---
			- abc
			- def

		"""), """
		TAML looks like: ---
- abc
- def
		"""

# ---------------------------------------------------------------------------
# --- test anonymous functions

tester.equal 212, new SmartInput("""
		input on:click={<<<}
			(event) ->
				console.log('click')

		"""), """
		input on:click={(event) -> console.log('click')}
		"""

# ---------------------------------------------------------------------------
# --- test named functions

tester.equal 224, new SmartInput("""
		input on:click={<<<}
			clickHandler = (event) ->
				console.log('click')

		"""), """
		input on:click={clickHandler = (event) -> console.log('click')}
		"""

# ---------------------------------------------------------------------------
# --- test ordinary block

tester.equal 236, new SmartInput("""
		lRecords = db.fetch("<<<");
			select ID,Name
			from Users

		console.dir(lRecords);
		"""), """
		lRecords = db.fetch("select ID,Name
from Users");
		console.dir(lRecords);
		"""

# ---------------------------------------------------------------------------
# --- test creating a custom HEREDOC section
#
#     e.g. with header line *** we'll create an upper-cased single line string

class CustomInput extends SmartInput

	mapHereDocUnknown: (lLines) ->

		assert isArray(lLines), "mapHereDocUnknown(): lLines not an array"
		if (lLines[0] == '***')
			lLines.shift()
			return @mapHereDocOneLiner(lLines).toUpperCase()
		else
			return undef    # unrecognized, pass to mapHereDocBlock()

tester.equal 264, new CustomInput("""
		str = "<<<"
			***
			select ID,Name
			from Users

		"""), """
		str = "SELECT ID,NAME FROM USERS"
		"""
