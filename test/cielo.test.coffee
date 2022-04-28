# cielo.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap} from '@jdeighan/mapper'
import {CieloMapper} from '@jdeighan/mapper/cielomapper'
import {convertCoffee} from '@jdeighan/mapper/coffee'
import {cieloCodeToJS, convertCielo} from '@jdeighan/mapper/cielo'

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
			return cieloCodeToJS(code, import.meta.url)

	tester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------
	# --- test retaining comments

	tester.equal 44, """
			# --- a comment
			y = x
			""", """
			# --- a comment
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test removing blank lines

	tester.equal 55, """
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

	tester.equal 70, """
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

	tester.equal 83, """
			x = 23
			y = x
					+ 5
			""", """
			x = 23
			y = x + 5
			"""

	# ------------------------------------------------------------------------
	# --- test use of backslash continuation lines

	tester.equal 95, """
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

	tester.equal 108, """
			x = 23
			y = "line __LINE__ in __FILE__"
			+ 5
			""", """
			x = 23
			y = "line 2 in cielo.test.js"
			+ 5
			"""

	tester.equal 118, """
			str = <<<
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 129, """
			str = <<<
				===
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 141, """
			str = <<<
				...this is a
					long line
			""", """
			str = "this is a long line"
			"""

	tester.equal 149, """
			lItems = <<<
				---
				- a
				- b
			""", """
			lItems = ["a","b"]
			"""

	tester.equal 158, """
			hItems = <<<
				---
				a: 13
				b: 42
			""", """
			hItems = {"a":13,"b":42}
			"""

	tester.equal 167, """
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

	tester.equal 180, """
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

	tester.equal 196, """
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

	tester.equal 209, """
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

	tester.equal 223, '''
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

	tester.equal 237, """
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
			return doMap(CieloMapper, import.meta.url, text)

	tester = new CieloTester('cielo.test')

	# ------------------------------------------------------------------------
	# Test function HEREDOC types

	tester.equal 267, """
			handler = <<<
				() ->
					return 42
			""", """
			handler = (function() {
				return 42;
				});
			"""

	tester.equal 277, """
			handler = <<<
				() -> return 42
			""", """
			handler = (function() {
				return 42;
				});
			"""

	tester.equal 286, """
			handler = <<<
				(x, y) ->
					return 42
			""", """
			handler = (function(x, y) {
				return 42;
				});
			"""

	)()

# ----------------------------------------------------------------------------

(() ->
	cieloCode = """
			# --- temp.cielo
			if fs.existsSync('file.txt')
				logger "file exists"
			"""

	jsCode = cieloCodeToJS(cieloCode, import.meta.url)

	simple.equal 314, jsCode, """
			import fs from 'fs';
			import {log as logger} from '@jdeighan/coffee-utils/log';
			// --- temp.cielo
			if (fs.existsSync('file.txt')) {
				logger("file exists");
			}
			"""
	)()
