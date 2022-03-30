# cielo.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap} from '@jdeighan/string-input'
import {setSymbolsRootDir} from '@jdeighan/string-input/symbols'
import {
	cieloCodeToJS, addImports, convertCielo,
	} from '@jdeighan/string-input/cielo'

rootDir = mydir(`import.meta.url`)
source = mkpath(rootDir, 'cielo.test.coffee')
setSymbolsRootDir rootDir

simple = new UnitTester('cielo.test.coffee')
# setDebugging 'cieloCodeToJS doMap'
convertCielo false

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
	class CieloTester extends UnitTesterNoNorm

		transformValue: (code) ->
			{jsCode, lNeededSymbols} = cieloCodeToJS(code, {source})
			return addImports(jsCode, lNeededSymbols)

	tester = new CieloTester('cielo.test')

	# ------------------------------------------------------------------------
	# --- test removing blank lines and comments

	tester.equal 47, """
			# --- a comment

			y = x
			""", """
			# --- a comment
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test include files

	tester.equal 59, """
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

	tester.equal 72, """
			x = 23
			y = x
					+ 5
			""", """
			x = 23
			y = x + 5
			"""

	# ------------------------------------------------------------------------
	# --- test use of backslash continuation lines

	tester.equal 84, """
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

	tester.equal 98, """
			x = 23
			y = "line LINE in FILE"
			+ 5
			""", """
			x = 23
			y = "line 2 in cielo.test.coffee"
			+ 5
			"""

	tester.equal 108, """
			str = <<<
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 119, """
			str = <<<
				===
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 131, """
			str = <<<
				...this is a
					long line
			""", """
			str = "this is a long line"
			"""

	tester.equal 139, """
			lItems = <<<
				---
				- a
				- b
			""", """
			lItems = ["a","b"]
			"""

	tester.equal 148, """
			hItems = <<<
				---
				a: 13
				b: 42
			""", """
			hItems = {"a":13,"b":42}
			"""

	tester.equal 157, """
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

	tester.equal 170, """
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

	tester.equal 186, """
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

	tester.equal 199, """
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

	tester.equal 213, '''
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

	tester.equal 227, """
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

	class CieloTester extends UnitTester

		transformValue: (text) ->
			return doMap(undef, text)

	tester = new CieloTester('cielo.test')

	# ------------------------------------------------------------------------
	# Test function HEREDOC types

	tester.equal 255, """
			handler = <<<
				() ->
					return 42
			""", """
			handler = (function() {
				return 42;
				});
			"""

	tester.equal 264, """
			handler = <<<
				() -> return 42
			""", """
			handler = (function() {
				return 42;
				});
			"""

	tester.equal 271, """
			handler = <<<
				(x, y) ->
					return 42
			""", """
			handler = (function(x, y) {
				return 42;
				});
			"""

	)()
