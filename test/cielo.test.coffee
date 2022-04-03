# cielo.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap, SmartMapper} from '@jdeighan/mapper'
import {setSymbolsRootDir} from '@jdeighan/mapper/symbols'
import {convertCoffee} from '@jdeighan/mapper/coffee'
import {cieloCodeToJS, addImports} from '@jdeighan/mapper/cielo'

rootDir = mydir(`import.meta.url`)
source = mkpath(rootDir, 'cielo.test.coffee')
setSymbolsRootDir rootDir

simple = new UnitTester('cielo.test.coffee')
convertCoffee false

# ---------------------------------------------------------------------------
# --- Features:
#        - REMOVE blank lines
#        - #include <file>
#        - handle continuation lines
#        - replace FILE, LINE and DIR
#        - stop on __END__
#        - handle HEREDOC - various types
#        - add auto-imports
# ---------------------------------------------------------------------------

(() ->
	class CieloTester extends UnitTester

		transformValue: (code) ->
			return cieloCodeToJS(code, {source})

	tester = new CieloTester('cielo.test')

	# ------------------------------------------------------------------------
	# --- test retaining comments

	tester.equal 45, """
			# --- a comment
			y = x
			""", """
			# --- a comment
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test removing blank lines

	tester.equal 57, """
			# --- a comment

			y = x
			""", """
			# --- a comment
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test include files - include.txt is:
	# y = f(2*3)
	# for i in range(5)
	#    y *= i

	tester.equal 73, """
			for x in [1,5]
				#include include.txt
			""", """
			for x in [1,5]
				y = f(2*3)
				for i in range(5)
					y *= i
			"""

	# ------------------------------------------------------------------------
	# --- test continuation lines

	tester.equal 92, """
			x = 23
			y = x
					+ 5
			""", """
			x = 23
			y = x + 5
			"""

	# ------------------------------------------------------------------------
	# --- test use of backslash continuation lines

	tester.equal 104, """
			x = 23
			y = x \
			+ 5
			""", """
			x = 23
			y = x \
			+ 5
			"""

	# ------------------------------------------------------------------------
	# --- test replacing LINE, FILE, DIR
	#     source = "c:/Users/johnd/string-input/test/cielo.test.coffee"

	tester.equal 118, """
			x = 23
			y = "line LINE in FILE"
			+ 5
			""", """
			x = 23
			y = "line 2 in cielo.test.coffee"
			+ 5
			"""

	tester.equal 128, """
			str = <<<
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 139, """
			str = <<<
				===
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 151, """
			str = <<<
				...this is a
					long line
			""", """
			str = "this is a long line"
			"""

	tester.equal 159, """
			lItems = <<<
				---
				- a
				- b
			""", """
			lItems = ["a","b"]
			"""

	tester.equal 168, """
			hItems = <<<
				---
				a: 13
				b: 42
			""", """
			hItems = {"a":13,"b":42}
			"""

	tester.equal 177, """
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

	tester.equal 190, """
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

	tester.equal 206, """
			x = 42
			func(x, "abc")
			__END__
			This is extraneous text
			which should be ignored
			""", """
			x = 42
			func(x, "abc")
			"""

	# --- Make sure triple quoted strings are passed through as is

	tester.equal 219, """
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

	tester.equal 233, '''
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

	tester.equal 247, """
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

	)()

# ---------------------------------------------------------------------------

(() ->

	convertCoffee true

	class CieloTester extends UnitTester

		transformValue: (text) ->
			return doMap(SmartMapper, text)

	tester = new CieloTester('cielo.test')

	# ------------------------------------------------------------------------
	# Test function HEREDOC types

	tester.equal 275, """
			handler = <<<
				() ->
					return 42
			""", """
			handler = (function() {
				return 42;
				});
			"""

	tester.equal 285, """
			handler = <<<
				() -> return 42
			""", """
			handler = (function() {
				return 42;
				});
			"""

	tester.equal 294, """
			handler = <<<
				(x, y) ->
					return 42
			""", """
			handler = (function(x, y) {
				return 42;
				});
			"""

	)()
