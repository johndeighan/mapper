# cielo.test.coffee

import {assert, LOG, LOGVALUE, setDebugging} from '@jdeighan/base-utils'
import {UnitTesterNorm, UnitTester, utest} from '@jdeighan/unit-tester'

import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {map} from '@jdeighan/mapper'
import {TreeMapper} from '@jdeighan/mapper/tree'
import {CieloToJSMapper} from '@jdeighan/mapper/cielo'

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
	class CieloTester extends UnitTester

		transformValue: (code) ->

			hInput = {
				source: import.meta.url
				content: code
				}
			return map(hInput, TreeMapper)

	cieloTester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------
	# --- test removing comments

	cieloTester.equal 41, """
			# --- a comment
			y = x
			""", """
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test removing blank lines

	cieloTester.equal 51, """
			y = x

			""", """
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test include files - include.txt is:
	# y = f(2*3)
	# for i in range(5)
	#    y *= i

	cieloTester.equal 64, """
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

	cieloTester.equal 77, """
			x = 23
			y = x
					+ 5
			""", """
			x = 23
			y = x + 5
			"""

	# ------------------------------------------------------------------------
	# --- can't use backslash continuation lines

	cieloTester.equal 89, """
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

	cieloTester.equal 102, """
			x = 23
			y = "line __LINE__ in __FILE__"
			+ 5
			""", """
			x = 23
			y = "line 2 in cielo.test.js"
			+ 5
			"""

	cieloTester.equal 112, """
			str = <<<
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	cieloTester.equal 123, """
			str = <<<
				===
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	cieloTester.equal 135, """
			str = <<<
				...this is a
					long line
			""", """
			str = "this is a long line"
			"""

	cieloTester.equal 143, """
			lItems = <<<
				---
				- a
				- b
			""", """
			lItems = ["a","b"]
			"""

	cieloTester.equal 152, """
			hItems = <<<
				---
				a: 13
				b: 42
			""", """
			hItems = {"a":13,"b":42}
			"""

	cieloTester.equal 161, """
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

	cieloTester.equal 174, """
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

	cieloTester.equal 190, """
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

	cieloTester.equal 203, """
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

	cieloTester.equal 217, '''
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

	cieloTester.equal 231, """
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

	# ------------------------------------------------------------------------
	# Test function HEREDOC types

	cieloTester.equal 246, """
			handler = <<<
				() ->
					return 42
			""", """
			handler = () ->
				return 42
			"""

	cieloTester.equal 255, """
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

	hInput = {
		source: import.meta.url
		content: cieloCode
		}
	jsCode = map(hInput, CieloToJSMapper)

	utest.equal 281, jsCode, """
			import fs from 'fs';
			import {log as logger} from '@jdeighan/coffee-utils/log';
			// --- temp.cielo
			if (fs.existsSync('file.txt')) {
			  logger("file exists");
			}
			"""
	)()

# ---------------------------------------------------------------------------

(() ->

	class CieloTester extends UnitTesterNorm

		transformValue: (code) ->

			hInput = {
				source: import.meta.url
				content: code
				}
			return map(hInput, CieloToJSMapper)

	cieloTester = new CieloTester('cielo.test')

	# --- Should auto-import mydir & mkpath from @jdeighan/coffee-utils/fs

	cieloTester.equal 309, """
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			import {mydir,mkpath} from '@jdeighan/coffee-utils/fs';
			var dir, filepath;
			dir = mydir(import.meta.url);
			filepath = mkpath(dir, 'test.txt');
			"""

	# --- But not if we're already importing them

	cieloTester.equal 321, """
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

	cieloTester.equal 335, """
			x = undef
			""", """
			import {undef} from '@jdeighan/coffee-utils';
			var x;
			x = undef;
			"""

	cieloTester.equal 343, """
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

	cieloTester.equal 358, """
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
# --- test subclassing TreeMapper
#     retain '# ||||' style comments

(() ->
	class MyMapper extends TreeMapper

		mapComment: (hNode) ->

			{str, uobj} = hNode
			{comment} = uobj
			if (comment.indexOf('||||') == 0)
				return str
			else
				return undef

	class CieloTester extends UnitTester

		transformValue: (code) ->

			hInput = {
				source: import.meta.url
				content: code
				}
			return map(hInput, MyMapper)

	cieloTester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------

	cieloTester.equal 400, """
			# --- a comment
			# |||| stuff
			y = x
			""", """
			# |||| stuff
			y = x
			"""
	)()

# ---------------------------------------------------------------------------
# --- test subclassing CieloToJSMapper
#     retain '# ||||' style comments

(() ->
	class MyMapper extends CieloToJSMapper

		mapComment: (hNode) ->

			{str, uobj} = hNode
			{comment} = uobj
			if (comment.indexOf('||||') == 0)
				return str
			else
				return undef

	class CieloTester extends UnitTester

		transformValue: (code) ->

			hInput = {
				source: import.meta.url
				content: code
				}
			return map(hInput, MyMapper)

	cieloTester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------

	cieloTester.equal 440, """
			# --- a comment
			# |||| stuff
			y = x
			""", """
			// |||| stuff
			var y;
			y = x;
			"""
	)()
