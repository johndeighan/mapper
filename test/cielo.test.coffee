# cielo.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap, CieloMapper} from '@jdeighan/mapper'
import {convertCoffee} from '@jdeighan/mapper/coffee'
import {cieloCodeToJS} from '@jdeighan/mapper/cielo'

simple = new UnitTesterNorm(import.meta.url)
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
	class CieloTester extends UnitTesterNorm

		transformValue: (code) ->
			{imports, jsCode} = cieloCodeToJS(code, import.meta.url)
			if isEmpty(imports)
				return jsCode
			else
				return [imports, jsCode].join("\n")

	tester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------
	# --- test retaining comments

	tester.equal 48, """
			# --- a comment
			y = x
			""", """
			# --- a comment
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test removing blank lines

	tester.equal 59, """
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

	tester.equal 74, """
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

	tester.equal 87, """
			x = 23
			y = x
					+ 5
			""", """
			x = 23
			y = x + 5
			"""

	# ------------------------------------------------------------------------
	# --- test use of backslash continuation lines

	tester.equal 99, """
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

	tester.equal 113, """
			x = 23
			y = "line __LINE__ in __FILE__"
			+ 5
			""", """
			x = 23
			y = "line 2 in cielo.test.js"
			+ 5
			"""

	tester.equal 123, """
			str = <<<
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 134, """
			str = <<<
				===
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 146, """
			str = <<<
				...this is a
					long line
			""", """
			str = "this is a long line"
			"""

	tester.equal 154, """
			lItems = <<<
				---
				- a
				- b
			""", """
			lItems = ["a","b"]
			"""

	tester.equal 163, """
			hItems = <<<
				---
				a: 13
				b: 42
			""", """
			hItems = {"a":13,"b":42}
			"""

	tester.equal 172, """
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

	tester.equal 185, """
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

	tester.equal 201, """
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

	tester.equal 214, """
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

	tester.equal 228, '''
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

	tester.equal 242, """
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

	class CieloTester extends UnitTesterNorm

		transformValue: (text) ->
			return doMap(CieloMapper, text, import.meta.url)

	tester = new CieloTester('cielo.test')

	# ------------------------------------------------------------------------
	# Test function HEREDOC types

	tester.equal 272, """
			handler = <<<
				() ->
					return 42
			""", """
			handler = (function() {
				return 42;
				});
			"""

	tester.equal 282, """
			handler = <<<
				() -> return 42
			""", """
			handler = (function() {
				return 42;
				});
			"""

	tester.equal 291, """
			handler = <<<
				(x, y) ->
					return 42
			""", """
			handler = (function(x, y) {
				return 42;
				});
			"""

	)()
