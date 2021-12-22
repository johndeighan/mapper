# cielo.test.coffee

import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {brewCielo} from '@jdeighan/string-input/cielo'

process.env.DIR_ROOT = mydir(`import.meta.url`)

simple = new UnitTester('cielo.test')

# ---------------------------------------------------------------------------

class CieloTester extends UnitTester

	transformValue: (code) ->
		hCielo = brewCielo(code)
		return joinBlocks(hCielo.importStmts, hCielo.code[0])

	normalize: (str) ->
		return str

tester = new CieloTester('cielo.test')

# ---------------------------------------------------------------------------
# --- test keeping blank lines and comments

tester.equal 29, """
		# --- a comment

		y = x
		""", """
		# --- a comment

		y = x
		"""

# ---------------------------------------------------------------------------
# --- test include files

tester.equal 42, """
		for x in [1,5]
			#include include.txt
		""", """
		for x in [1,5]
			y = f(2*3)
			for i in range(5)
				y *= i
		"""

# ---------------------------------------------------------------------------
# --- test continuation lines

tester.equal 55, """
		x = 23
		y = x
				+ 5
		""", """
		x = 23
		y = x + 5
		"""

# ---------------------------------------------------------------------------
# --- test use of backslash continuation lines

tester.equal 67, """
		x = 23
		y = x \
		+ 5
		""", """
		x = 23
		y = x \
		+ 5
		"""

# ---------------------------------------------------------------------------
# --- test auto-import of symbols from file '.symbols'

tester.equal 80, """
		x = 23
		logger x
		""", """
		import {log as logger} from '@jdeighan/coffee-utils/log'
		x = 23
		logger x
		"""
