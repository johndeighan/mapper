# cielo.test.coffee

import {undef, isEmpty, nonEmpty} from '@jdeighan/base-utils'
import {assert} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {slurp} from '@jdeighan/base-utils/fs'
import {UnitTester, equal, like} from '@jdeighan/base-utils/utest'

import {map} from '@jdeighan/mapper'
import {TreeMapper} from '@jdeighan/mapper/tree'
import {
	CieloToJSCodeMapper, CieloToJSExprMapper,
	cieloToJSCode, cieloToJSExpr,
	} from '@jdeighan/mapper/cielo'

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

			hSource = {content: code, source: 'cielo.test.js'}
			return map(hSource, TreeMapper)

	cieloTester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------
	# --- test removing comments

	cieloTester.equal """
			# --- a comment
			y = x
			""", """
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test removing blank lines

	cieloTester.equal """
			y = x

			""", """
			y = x
			"""

	# ------------------------------------------------------------------------
	# --- test include files - include.txt is:
	# y = f(2*3)
	# for i in range(5)
	#    y *= i

	cieloTester.equal """
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

	cieloTester.equal """
			x = 23
			y = x
					+ 5
			""", """
			x = 23
			y = x + 5
			"""

	# ------------------------------------------------------------------------
	# --- can't use backslash continuation lines

	cieloTester.equal """
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

	cieloTester.equal """
			x = 23
			y = "line __LINE__ in __FILE__"
			+ 5
			""", """
			x = 23
			y = "line 2 in cielo.test.js"
			+ 5
			"""

	cieloTester.equal """
			str = <<<
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	cieloTester.equal """
			str = <<<
				===
				abc
				def

			x = 42
			""", """
			str = "abc\\ndef"
			x = 42
			"""

	cieloTester.equal """
			str = <<<
				...this is a
					long line
			""", """
			str = "this is a long line"
			"""

	cieloTester.equal """
			lItems = <<<
				---
				- a
				- b
			""", """
			lItems = ["a","b"]
			"""

	cieloTester.equal """
			hItems = <<<
				---
				a: 13
				b: 42
			""", """
			hItems = {"a":13,"b":42}
			"""

	cieloTester.equal """
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

	cieloTester.equal """
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

	cieloTester.equal """
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

	cieloTester.equal """
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

	cieloTester.equal '''
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

	cieloTester.equal """
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

# ----------------------------------------------------------------------------
# --- test contents of .symbols

like slurp('./test/.symbols'), """
	fs
		*fs exists readFile

	@jdeighan/base-utils/fs
		mkpath slurp barf

	@jdeighan/coffee-utils
		say undef

	@jdeighan/coffee-utils/fs
		mydir

	@jdeighan/coffee-utils/log
		log/logger
	"""

# ----------------------------------------------------------------------------

(() ->
	hInput = {
		# --- must supply source,
		#     else wrong .symbols file is used
		source: import.meta.url
		content: """
			# --- temp.cielo
			if fs.existsSync('file.txt')
				logger "file exists"
			"""
		}
	jsCode = cieloToJSCode(hInput)

	like jsCode, """
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

	class CieloTester extends UnitTester

		transformValue: (code) ->

			hInput = {
				# --- must supply source, else wrong .symbols file is used
				source: import.meta.url
				content: code
				}
			return cieloToJSCode(hInput)

	cieloTester = new CieloTester('cielo.test')

	# --- Should auto-import mydir & mkpath from @jdeighan/coffee-utils/fs

	cieloTester.like """
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			import {mkpath} from '@jdeighan/base-utils/fs';
			import {mydir} from '@jdeighan/coffee-utils/fs';
			var dir, filepath;
			dir = mydir(import.meta.url);
			filepath = mkpath(dir, 'test.txt');
			"""

	# --- But not if we're already importing them

	cieloTester.like """
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

	cieloTester.equal """
			x = undef
			""", """
			import {undef} from '@jdeighan/coffee-utils';
			var x;
			x = undef;
			"""

	cieloTester.equal """
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

	cieloTester.equal """
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

			{str, _commentText} = hNode
			if (_commentText.indexOf('||||') == 0)
				return str
			else
				return undef

	class CieloTester extends UnitTester

		transformValue: (code) ->

			return map(code, MyMapper)

	cieloTester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------

	cieloTester.equal """
			# --- a comment
			# |||| stuff
			y = x
			""", """
			# |||| stuff
			y = x
			"""
	)()

# ---------------------------------------------------------------------------
# --- test subclassing CieloToJSCodeMapper
#     retain '# ||||' style comments

(() ->
	class MyMapper extends CieloToJSCodeMapper

		mapComment: (hNode) ->

			{str, _commentText} = hNode
			if (_commentText.indexOf('||||') == 0)
				return str
			else
				return undef

	class CieloTester extends UnitTester

		transformValue: (code) ->

			return map(code, MyMapper)

	cieloTester = new CieloTester(import.meta.url)

	# ------------------------------------------------------------------------

	cieloTester.equal """
			# --- a comment
			# |||| stuff
			y = x
			""", """
			// |||| stuff
			var y;
			y = x;
			"""
	)()
