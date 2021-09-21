# cielo.test.coffee

import {strict as assert} from 'assert'

import {
	undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {brewCielo} from '@jdeighan/string-input/coffee'

dir = mydir(`import.meta.url`)
process.env.DIR_MARKDOWN = mkpath(dir, 'markdown')
process.env.DIR_DATA = mkpath(dir, 'data')

simple = new UnitTester()

###
	brewCielo() should handle the following:
		- should NOT remove blank lines and comments
		- #include <file> statements, when DIR_* env vars are set
		- patch {{FILE}} with the name of the input file
		- patch {{LINE}} with the line number
		- handle continuation lines
		- handle HEREDOC
		- add auto-imports
###

# ---------------------------------------------------------------------------

class CieloTester extends UnitTester

	transformValue: (code) ->
		return brewCielo(code)

	normalize: (line) ->  # disable normalizing, to check proper indentation
		return line

tester = new CieloTester()

# ---------------------------------------------------------------------------
# --- Should NOT remove blank lines and comments

tester.equal 45, """
		x = 42
		# --- a blank line

		console.log x
		""", """
		x = 42
		# --- a blank line

		console.log x
		"""

# ---------------------------------------------------------------------------
# --- maintain indentation - simple

tester.equal 60, """
		if (x==42)
			console.log x
		""", """
		if (x==42)
			console.log x
		"""

# ---------------------------------------------------------------------------
# --- maintain indentation - complex

tester.equal 71, """
		x = 42
		if (x==42)
			console.log x
			if (x > 100)
				console.log "x is big"
		""", """
		x = 42
		if (x==42)
			console.log x
			if (x > 100)
				console.log "x is big"
		"""

# ---------------------------------------------------------------------------
# --- handle #include of *.txt files

# setDebugging "get"

tester.equal 90, """
		if (x==42)
			#include code.txt
		""", """
		if (x==42)
			y = 5
			if (y > 100)
				console.log "y is big"
		"""

# ---------------------------------------------------------------------------
