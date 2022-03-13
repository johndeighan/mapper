# cielo.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {brewCieloStr} from '@jdeighan/string-input/cielo'

rootDir = process.env.DIR_ROOT = mydir(`import.meta.url`)
source = mkpath(rootDir, 'cielo.test.coffee')

simple = new UnitTester('cielo.test.coffee')

# ---------------------------------------------------------------------------

class CieloTester extends UnitTesterNoNorm

	transformValue: (code) ->
		return brewCieloStr([code], {source})

tester = new CieloTester('cielo.test')

# ---------------------------------------------------------------------------
# --- Features:
#        - REMOVE blank lines and comments
#        - #include <file>
#        - handle continuation lines
#        - replace replace {{FILE}}, {{LINE}} and {{DIR}}
#        - handle HEREDOC - various types
#        - stop on __END__
#        - add auto-imports
#        - handle <== (blocks and statements)
# ---------------------------------------------------------------------------
# --- test removing blank lines and comments

tester.equal 36, """
		# --- a comment

		y = x
		""", """
		y = x
		"""

# ---------------------------------------------------------------------------
# --- test removing cielo-specific comments

tester.equal 47, """
		### --- a comment
			### remove this
		y = x
		""", """
		y = x
		"""

# ---------------------------------------------------------------------------
# --- test include files

tester.equal 58, """
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

tester.equal 71, """
		x = 23
		y = x
				+ 5
		""", """
		x = 23
		y = x + 5
		"""

# ---------------------------------------------------------------------------
# --- test use of backslash continuation lines

tester.equal 83, """
		x = 23
		y = x \
		+ 5
		""", """
		x = 23
		y = x \
		+ 5
		"""

# ---------------------------------------------------------------------------
# --- test replacing {{LINE}}, {{FILE}}, {{DIR}}
#     source is set to "c:/Users/johnd/string-input/test/cielo.test.coffee"

tester.equal 97, """
		x = 23
		y = "line {{LINE}} in {{FILE}}"
		+ 5
		""", """
		x = 23
		y = "line 2 in cielo.test.coffee"
		+ 5
		"""

# ---------------------------------------------------------------------------
# Test various HEREDOC types

tester.equal 110, """
		str = <<<
			abc
			def

		x = 42
		""", """
		str = "abc\\ndef"
		x = 42
		"""

tester.equal 121, """
		str = <<<
			===
			abc
			def

		x = 42
		""", """
		str = "abc\\ndef"
		x = 42
		"""

tester.equal 133, """
		func = <<<
			() ->
				return 42
		""", """
		func = () ->
			return 42
		"""

tester.equal 142, """
		func = <<<
			() -> return 42
		""", """
		func = () -> return 42
		"""

tester.equal 149, """
		func = <<<
			(x, y) ->
				return 42
		""", """
		func = (x, y) ->
			return 42
		"""

tester.equal 158, """
		str = <<<
			...this is a
				long line
		""", """
		str = "this is a long line"
		"""

tester.equal 166, """
		lItems = <<<
			---
			- a
			- b
		""", """
		lItems = ["a","b"]
		"""

tester.equal 175, """
		hItems = <<<
			---
			a: 13
			b: 42
		""", """
		hItems = {"a":13,"b":42}
		"""

tester.equal 184, """
		lItems = <<<
			---
			-
				a: 13
				b: 42
			-
				c: 2
				d: 3
		""", """
		lItems = [{"a":13,"b":42},{"c":2,"d":3}]
		"""

tester.equal 197, """
		func(<<<, <<<, <<<)
			a block
			of text

			---
			- a
			- b

			---
			a: 13
			b: 42
		""", """
		func("a block\\nof text", ["a","b"], {"a":13,"b":42})
		"""

tester.equal 213, """
		x = 42
		func(x, "abc")
		__END__
		This is extraneous text
		which should be ignored
		""", """
		x = 42
		func(x, "abc")
		"""

# --- Should auto-import mydir & mkpath from @jdeighan/coffee-utils/fs

tester.equal 226, """
		dir = mydir(import.meta.url)
		filepath = mkpath(dir, 'test.txt')
		""", """
		import {mydir,mkpath} from '@jdeighan/coffee-utils/fs'
		dir = mydir(import.meta.url)
		filepath = mkpath(dir, 'test.txt')
		"""

# --- But not if we're already importing them

tester.equal 237, """
		import {mkpath,mydir} from '@jdeighan/coffee-utils/fs'
		dir = mydir(import.meta.url)
		filepath = mkpath(dir, 'test.txt')
		""", """
		import {mkpath,mydir} from '@jdeighan/coffee-utils/fs'
		dir = mydir(import.meta.url)
		filepath = mkpath(dir, 'test.txt')
		"""

# --- Handling reactive expressions:

tester.equal 249, """
		<==
			x = func(2, 4)
		console.log x
		""", """
		`$:{`
		x = func(2, 4)
		`}`
		console.log x
		"""

tester.equal 260, """
		x <== func(2, 4)
		console.log x
		""", """
		`$:{`
		x = func(2, 4)
		`}`
		console.log x
		"""

# --- Make sure triple quoted strings are passed through as is

tester.equal 272, """
		str = \"\"\"
			this is a
			long string
			\"\"\"
		""", """
		str = \"\"\"
			this is a
			long string
			\"\"\"
		"""

# --- Make sure triple quoted strings are passed through as is

tester.equal 286, '''
		str = """
			this is a
			long string
			"""
		''', '''
		str = """
			this is a
			long string
			"""
		'''

# --- Make sure triple quoted strings are passed through as is

tester.equal 300, """
		str = '''
			this is a
			long string
			'''
		""", """
		str = '''
			this is a
			long string
			'''
		"""
