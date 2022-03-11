# cielo.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {brewCieloStr} from '@jdeighan/string-input/cielo'

process.env.DIR_ROOT = mydir(`import.meta.url`)
simple = new UnitTester('cielo.test')

# ---------------------------------------------------------------------------

class CieloTester extends UnitTester

	transformValue: (code) ->
		return brewCieloStr(code)

	normalize: (str) ->    # disable normalizing
		return str

tester = new CieloTester('cielo.test')

# ---------------------------------------------------------------------------
# --- Features to test:
#        1. KEEP blank lines and comments
#        2. #include <file>
#        3. replace {{FILE}} and {{LINE}}
#        4. handle continuation lines
#        5. handle HEREDOC
#        6. stop on __END__
#        7. add auto-imports

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
# --- test removing cielo-specific comments

tester.equal 29, """
		### --- a comment
			### remove this
		y = x
		""", """
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
