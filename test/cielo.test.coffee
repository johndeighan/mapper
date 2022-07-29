# cielo.test.coffee

import {assert} from '@jdeighan/unit-tester/utils'
import {UnitTesterNorm, UnitTester, simple} from '@jdeighan/unit-tester'

import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap} from '@jdeighan/mapper'
import {
	cieloCodeToJS, cieloCodeToCoffee,
	} from '@jdeighan/mapper/cielo'
import {TreeWalker} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------
# --- Features:
#        - REMOVE blank lines
#        - #include <file>
#        - handle continuation lines
#        - replace FILE, LINE, DIR and SRC
#        - stop on __END__
#        - handle HEREDOC - various types
#        - add auto-imports
# ---------------------------------------------------------------------------

(() ->
	class CieloTester extends UnitTesterNorm

		transformValue: (code) ->
			return cieloCodeToCoffee(code, import.meta.url)

	tester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------
	# --- test removing comments

	tester.equal 41, """
			# --- a comment
			y = x
			""", """
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test removing blank lines

	tester.equal 52, """
			y = x

			""", """
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test include files - include.txt is:
	# y = f(2*3)
	# for i in range(5)
	#    y *= i

	tester.equal 65, """
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

	tester.equal 78, """
			x = 23
			y = x
					+ 5
			""", """
			x = 23
			y = x + 5
			"""

	# ------------------------------------------------------------------------
	# --- can't use backslash continuation lines

	tester.equal 90, """
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

	tester.equal 103, """
			x = 23
			y = "line __LINE__ in __FILE__"
			+ 5
			""", """
			x = 23
			y = "line 2 in cielo.test.js"
			+ 5
			"""

	tester.equal 113, """
			str = <<<
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 124, """
			str = <<<
				===
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	tester.equal 136, """
			str = <<<
				...this is a
					long line
			""", """
			str = "this is a long line"
			"""

	tester.equal 144, """
			lItems = <<<
				---
				- a
				- b
			""", """
			lItems = ["a","b"]
			"""

	tester.equal 153, """
			hItems = <<<
				---
				a: 13
				b: 42
			""", """
			hItems = {"a":13,"b":42}
			"""

	tester.equal 162, """
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

	tester.equal 175, """
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

	tester.equal 191, """
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

	tester.equal 204, """
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

	tester.equal 218, '''
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

	tester.equal 232, """
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

	class CieloTester extends UnitTesterNorm

		transformValue: (text) ->
			return doMap(TreeWalker, import.meta.url, text)

	tester = new CieloTester('cielo.test')

	# ------------------------------------------------------------------------
	# Test function HEREDOC types

	tester.equal 260, """
			handler = <<<
				() ->
					return 42
			""", """
			handler = () ->
				return 42
			"""

	tester.equal 269, """
			handler = <<<
				(x, y) ->
					return 42
			""", """
			handler = (x, y) ->
				return 42
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

	simple.equal 291, jsCode, """
			import fs from 'fs';
			import {log as logger} from '@jdeighan/coffee-utils/log';
			if (fs.existsSync('file.txt')) {
			  logger("file exists");
			}
			"""
	)()

# ---------------------------------------------------------------------------

(() ->

	class CieloTester extends UnitTesterNorm

		transformValue: (text) ->
			return cieloCodeToJS(text, import.meta.url)

	tester = new CieloTester('cielo.test')

	# --- Should auto-import mydir & mkpath from @jdeighan/coffee-utils/fs

	tester.equal 314, """
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			import {mydir,mkpath} from '@jdeighan/coffee-utils/fs';
			var dir, filepath;
			dir = mydir(import.meta.url);
			filepath = mkpath(dir, 'test.txt');
			"""

	# --- But not if we're already importing them

	tester.equal 326, """
			import {mkpath,mydir} from '@jdeighan/coffee-utils/fs'
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			var dir, filepath;
			import {
				mkpath,
				mydir
				} from '@jdeighan/coffee-utils/fs';
			dir = mydir(import.meta.url);
			filepath = mkpath(dir, 'test.txt');
			"""

	tester.equal 340, """
			x = undef
			""", """
			import {undef} from '@jdeighan/coffee-utils';
			var x;
			x = undef;
			"""

	tester.equal 348, """
			x = undef
			contents = 'this is a file'
			fs.writeFileSync('temp.txt', contents, {encoding: 'utf8'})
			""", """
			import fs from 'fs';
			import {undef} from '@jdeighan/coffee-utils';
			var contents, x;
			x = undef;
			contents = 'this is a file';
			fs.writeFileSync('temp.txt', contents, {
				encoding: 'utf8'
				});
			"""

	tester.equal 363, """
			x = 23
			logger x
			""", """
			import {log as logger} from '@jdeighan/coffee-utils/log';
			var x;
			x = 23;
			logger(x);
			"""

	)()

# ---------------------------------------------------------------------------
# --- test premapper

(() ->
	class CieloTester extends UnitTester

		transformValue: (code) ->

			# --- define a custom premapper that retains '# ||||' style comments
			class MyPreMapper extends TreeWalker

				mapComment: (hNode) ->
					{str, comment} = hNode
					if (comment.indexOf('||||') == 0)
						return str
					else
						return undef

			hOptions = {premapper: MyPreMapper}
			return cieloCodeToCoffee(code, import.meta.url, hOptions)

	tester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------
	# --- test removing comments

	tester.equal 399, """
			# --- a comment
			# |||| stuff
			y = x
			""", """
			# |||| stuff
			y = x
			"""
	)()
