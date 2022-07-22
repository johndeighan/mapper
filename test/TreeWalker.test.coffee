# TreeWalker.test.coffee

import {UnitTester, UnitTesterNorm, simple} from '@jdeighan/unit-tester'
import {
	assert, croak, undef, pass, OL, defined,
	isEmpty, nonEmpty, isString,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {LOG} from '@jdeighan/coffee-utils/log'
import {
	debug, setDebugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {taml} from '@jdeighan/coffee-utils/taml'

import {doMap} from '@jdeighan/mapper'
import {TreeWalker} from '@jdeighan/mapper/tree'
import {SimpleMarkDownMapper} from '@jdeighan/mapper/markdown'
import {addStdHereDocTypes} from '@jdeighan/mapper/heredoc'

addStdHereDocTypes()

###
	class TreeWalker should handle the following:
		- remove empty lines, retain comments
		- extension lines
		- can override @mapStr() - used in @getAll()
		- call @walk() to walk the tree
		- can override beginWalk(), visit(), endVisit(), endWalk()
###

# ---------------------------------------------------------------------------
# Test TreeWalker.get()

(() ->
	walker = new TreeWalker(import.meta.url, """
			# --- a comment

			abc
				def
					ghi
			""")

	simple.like 48, walker.get(), {
		line:  '# --- a comment'
		prefix: ''
		str:  '# --- a comment'
		level: 0
		type:  'comment'
		}
	simple.like 55, walker.get(), {
		line:  'abc'
		prefix: ''
		str:  'abc'
		level: 0
		}
	simple.like 61, walker.get(), {
		line:  '\tdef'
		prefix: '\t'
		str:  'def'
		level: 1
		}
	simple.like 67, walker.get(), {
		line:  '\t\tghi'
		prefix: '\t\t'
		str:  'ghi'
		level: 2
		}
	simple.equal 73, walker.get(), undef
	)()

# ---------------------------------------------------------------------------
# Test __END__ and extension lines with TreeWalker.get()

(() ->
	walker = new TreeWalker(import.meta.url, """
			abc
					def
				ghi
			__END__
					ghi
			""")

	# --- get() should return {uobj, level}

	simple.like 90, walker.get(), {
		line:   'abc def'
		prefix: ''
		str: 'abc def'
		level: 0
		}
	simple.like 96, walker.get(), {
		line:   '\tghi'
		prefix: '\t'
		str: 'ghi'
		level: 1
		}
	simple.equal 102, walker.get(), undef
	)()

# ---------------------------------------------------------------------------
# __END__ only works with no identation

(() ->
	walker = new TreeWalker(import.meta.url, """
			abc
					def
				ghi
				__END__
					ghi
			""")

	# --- get() should return {uobj, level}

	simple.like 119, walker.get(), {
		level: 0
		str:   'abc def'
		}
	simple.like 123, walker.get(), {
		level: 1
		str:   'ghi'
		}
	simple.like 127, walker.get(), {
		level: 1
		str:   '__END__'
		}
	simple.like 131, walker.get(), {
		level: 2
		str:   'ghi'
		}
	simple.equal 135, walker.get(), undef
	)()

# ---------------------------------------------------------------------------

(() ->

	class Tester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	tester = new Tester()

	# ---------------------------------------------------------------------------
	# --- Test basic reading till EOF

	tester.equal 153, """
			abc
			def
			""", """
			abc
			def
			"""

	tester.equal 161, """
			abc

			def
			""", """
			abc
			def
			"""
	)()

# ---------------------------------------------------------------------------
# Test empty line handling

(() ->
	class MyWalker extends TreeWalker

		# --- This removes blank lines
		handleEmptyLine: () ->

			debug "in MyWalker.handleEmptyLine()"
			return undef

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyWalker, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	block = """
			abc

			def
			"""

	simple.equal 201, doMap(MyWalker, import.meta.url, block), """
			abc
			def
			"""

	tester.equal 206, block, """
			abc
			def
			"""

	)()

# ---------------------------------------------------------------------------
# Test comment handling

(() ->
	class MyWalker extends TreeWalker

		isComment: (line) ->

			# --- comments start with //
			return line.match(///^ \s* \/ \/ ///)

		handleComment: (line) ->

			# --- remove comments
			return undef

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyWalker, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	block = """
			// a comment - should be removed
			//also a comment
			# not a comment
			abc
			def
			"""

	simple.equal 249, doMap(MyWalker, import.meta.url, block), """
			# not a comment
			abc
			def
			"""

	tester.equal 255, block, """
			# not a comment
			abc
			def
			"""

	)()

# ---------------------------------------------------------------------------
# Test command handling

(() ->
	class MyWalker extends TreeWalker

		isCmd: (str, hLine) ->
			# --- commands consist of '-' + one whitespace char + word
			if (lMatches = str.match(///^ - \s (\w+) $///))
				[_, cmd] = lMatches
				hLine.cmd = cmd
				hLine.argstr = hLine.prefix = ''
				return true
			else
				return false

		# .......................................................

		handleCmd: (hLine) ->

			return "COMMAND: #{hLine.cmd}"

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->
			return doMap(MyWalker, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	block = """
			# don't remove this

			abc
			- command
			def
			"""

	tester.equal 309, block, """
			# don't remove this
			abc
			COMMAND: command
			def
			"""

	)()

# ---------------------------------------------------------------------------
# try retaining indentation for mapped lines

(()->

	# --- NOTE: If you don't override unmapObj(), then
	#           mapStr() must return {str: <string>, level: <level>}
	#           or undef to ignore the line

	class MyWalker extends TreeWalker

		# --- This maps all non-empty lines to the string 'x'
		#     and removes all empty lines
		mapStr: (str, level) ->

			debug "enter mapStr('#{str}', #{level}"
			if isEmpty(str)
				debug "return undef from mapStr() - empty line"
				return undef
			else
				debug "return 'x' from mapStr()"
				return 'x'

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyWalker, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	tester.equal 353, """
			abc
				def

			ghi
			""", """
			x
				x
			x
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test ability to access 'this' object from a walker
#     Goal: remove not only blank lines, but also the line following

(()->

	class MyWalker extends TreeWalker

		# --- Remove blank lines PLUS the line following a blank line
		handleEmptyLine: (hLine) ->

			follow = @fetch()
			return undef    # remove empty lines

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyWalker, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	tester.equal 391, """
			abc

			def
			ghi
			""", """
			abc
			ghi
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test #include

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	# ..........................................................

	tester = new MyTester()

	tester.equal 417, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test getAll()

(() ->

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			walker = new TreeWalker(import.meta.url, block)
			return walker.getAll()

	tester = new MyTester()

	tester.like 446, """
			abc
				def
					ghi
			jkl
			""", taml("""
			---
			-
				level: 0
				str: 'abc'
			-
				level: 1
				str: 'def'
			-
				level: 2
				str: 'ghi'
			-
				level: 0
				str: 'jkl'
			""")

	)()

# ---------------------------------------------------------------------------

(() ->

	walker = new TreeWalker(import.meta.url, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	simple.like 482, walker.peek(), {level:0, str: 'if (x == 2)'}
	simple.like 483, walker.get(),  {level:0, str: 'if (x == 2)'}

	simple.like 485, walker.peek(), {level:1, str: 'doThis'}
	simple.like 486, walker.get(),  {level:1, str: 'doThis'}

	simple.like 488, walker.peek(), {level:1, str: 'doThat'}
	simple.like 489, walker.get(),  {level:1, str: 'doThat'}

	simple.like 491, walker.peek(), {level:2, str: 'then this'}
	simple.like 492, walker.get(),  {level:2, str: 'then this'}

	simple.like 494, walker.peek(), {level:0, str: 'while (x > 2)'}
	simple.like 495, walker.get(),  {level:0, str: 'while (x > 2)'}

	simple.like 497, walker.peek(), {level:1, str: '--x'}
	simple.like 498, walker.get(),  {level:1, str: '--x'}

	)()

# ---------------------------------------------------------------------------
# --- Test fetchBlockAtLevel()

(() ->

	walker = new TreeWalker(import.meta.url, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	simple.like 516, walker.get(), {
		level: 0
		str:   'if (x == 2)'
		}

	simple.equal 521, walker.fetchBlockAtLevel(1), """
			doThis
			doThat
				then this
			"""

	simple.like 527, walker.get(), {
		level: 0
		str:   'while (x > 2)'
		}

	simple.equal 532, walker.fetchBlockAtLevel(1), "--x"
	)()

# ---------------------------------------------------------------------------
# --- Test fetchBlockAtLevel() with mapping

(() ->

	class MyWalker extends TreeWalker

		mapStr: (str, level) ->
			if (lMatches = str.match(///^
					(if | while)
					\s*
					(.*)
					$///))
				[_, cmd, cond] = lMatches
				return {cmd, cond}
			else
				return str

	walker = new MyWalker(import.meta.url, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	simple.like 562, walker.get(), {
			level: 0
			line: {
				cmd: 'if'
				cond: '(x == 2)'
				}
			}
	simple.equal 569, walker.fetchBlockAtLevel(1), """
			doThis
			doThat
				then this
			"""
	simple.like 574, walker.get(), {
			level: 0
			line: {
				cmd: 'while',
				cond: '(x > 2)'
				}
			}
	simple.equal 581, walker.fetchBlockAtLevel(1), "--x"
	simple.equal 582, walker.get(), undef
	)()

# ---------------------------------------------------------------------------
# --- Test HEREDOC

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	# ..........................................................

	tester = new MyTester()

	tester.equal 667, """
			abc
			if x == <<<
				abc
				def

			def
			""", """
			abc
			if x == "abc\\ndef"
			def
			"""

	tester.equal 680, """
			abc
			if x == <<<
				===
				abc
				def

			def
			""", """
			abc
			if x == "abc\\ndef"
			def
			"""

	tester.equal 694, """
			abc
			if x == <<<
				...
				abc
				def

			def
			""", """
			abc
			if x == "abc def"
			def
			"""

	)()

# ---------------------------------------------------------------------------
# --- A more complex example

class HtmlMapper extends TreeWalker

	mapStr: (str, level) ->

		debug "enter MyWalker.mapStr()", str, level
		lMatches = str.match(///^
				(\S+)     # the tag
				(?:
					\s+    # some whitespace
					(.*)   # everything else
					)?     # optional
				$///)
		assert defined(lMatches), "missing HTML tag"
		[_, tag, text] = lMatches
		hResult = {tag, @level}
		switch tag
			when 'body'
				assert isEmpty(text), "body tag doesn't allow content"
			when 'p', 'div'
				if nonEmpty(text)
					hResult.body = text
			when 'div:markdown'
				hResult.tag = 'div'
				body = @fetchBlockAtLevel(level+1)
				debug "body", body
				if nonEmpty(body)
					md = doMap(SimpleMarkDownMapper, import.meta.url, body)
					debug "md", md
					hResult.body = md
			else
				croak "Unknown tag: #{OL(tag)}"

		debug "return from MyWalker.mapStr()", hResult
		return hResult

	# .......................................................

	visit: (hLine, hUser, lStack) ->

		{str, uobj, level, type} = hLine
		switch type
			when 'comment'
				if lMatches = str.match(///^
						\#
						(.*)
						$///)
					[_, str] = lMatches
					return indented("<!-- #{str.trim()} -->", level)
				else
					return undef
		lParts = [indented("<#{uobj.tag}>", level)]
		if nonEmpty(uobj.body)
			lParts.push indented(uobj.body, level+1)
		result = arrayToBlock(lParts)
		debug 'result', result
		return result

	# .......................................................

	endVisit: (hLine, hUser, lStack) ->

		{uobj, level, type} = hLine
		if (type == 'comment')
			return undef

		return indented("</#{uobj.tag}>", level)

# ---------------------------------------------------------------------------

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(HtmlMapper, import.meta.url, block)

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 793, """
			body
				# a comment

				div:markdown
					A title
					=======

					some text

				div
					p more text
			""", """
			<body>
				<!-- a comment -->
				<div>
					<h1>A title</h1>
					<p>some text</p>
				</div>
				<div>
					<p>
						more text
					</p>
				</div>
			</body>
			"""

	)()

# ---------------------------------------------------------------------------
# --- test #ifdef and #ifndef

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	tester = new MyTester()

	tester.equal 835, """
			abc
			#ifdef something
				def
				ghi
			#ifndef something
				xyz
			""", """
			abc
			xyz
			"""

	)()
