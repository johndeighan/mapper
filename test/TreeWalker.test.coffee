# TreeWalker.test.coffee

import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {
	assert, croak, undef, pass, OL, defined,
	isEmpty, nonEmpty, isString,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {
	debug, setDebugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {taml} from '@jdeighan/coffee-utils/taml'

import {doMap} from '@jdeighan/mapper'
import {TreeWalker, TraceWalker} from '@jdeighan/mapper/tree'
import {SimpleMarkDownMapper} from '@jdeighan/mapper/markdown'

simple = new UnitTester()

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
	walker = new TreeWalker(undef, """
			# --- comment, followed by blank line

			abc
				def
					ghi
			""")

	# --- get() should return {uobj, level}

	simple.equal 47, walker.get(), {
		level:  0
		uobj:    'abc'
		lineNum: 3
		}
	simple.equal 52, walker.get(), {
		level:  1
		uobj:    'def'
		lineNum: 4
		}
	simple.equal 57, walker.get(), {
		level:  2
		uobj:    'ghi'
		lineNum: 5
		}
	simple.equal 62, walker.get(), undef
	)()

# ---------------------------------------------------------------------------
# Test __END__ and extension lines with TreeWalker.get()

(() ->
	walker = new TreeWalker(undef, """
			abc
					def
				ghi
			__END__
					ghi
			""")

	# --- get() should return {uobj, level}

	simple.equal 79, walker.get(), {
		level: 0
		uobj:   'abc def'
		lineNum: 1
		}
	simple.equal 84, walker.get(), {
		level: 1
		uobj:   'ghi'
		lineNum: 3
		}
	simple.equal 89, walker.get(), undef
	)()

# ---------------------------------------------------------------------------
# __END__ only works with no identation

(() ->
	walker = new TreeWalker(undef, """
			abc
					def
				ghi
				__END__
					ghi
			""")

	# --- get() should return {uobj, level, lineNum}

	simple.equal 106, walker.get(), {
		level: 0
		uobj:   'abc def'
		lineNum: 1
		}
	simple.equal 111, walker.get(), {
		level: 1
		uobj:   'ghi'
		lineNum: 3
		}
	simple.equal 116, walker.get(), {
		level: 1
		uobj:   '__END__'
		lineNum: 4
		}
	simple.equal 121, walker.get(), {
		level: 2
		uobj:   'ghi'
		lineNum: 5
		}
	simple.equal 126, walker.get(), undef
	)()

# ---------------------------------------------------------------------------

(() ->

	class Tester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	tester = new Tester()

	# ---------------------------------------------------------------------------
	# --- Test basic reading till EOF

	tester.equal 144, """
			abc
			def
			""", """
			abc
			def
			"""

	tester.equal 152, """
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
	class MyMapper extends TreeWalker

		# --- This removes blank lines
		handleEmptyLine: () ->

			debug "in MyMapper.handleEmptyLine()"
			return undef

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyMapper, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	block = """
			abc

			def
			"""

	simple.equal 192, doMap(MyMapper, import.meta.url, block), """
			abc
			def
			"""

	tester.equal 197, block, """
			abc
			def
			"""

	)()

# ---------------------------------------------------------------------------
# Test comment handling

(() ->
	class MyMapper extends TreeWalker

		isComment: (line) ->

			# --- comments start with //
			return line.match(///^ \s* \/ \/ ///)

		handleComment: (line) ->

			# --- remove comments
			return undef

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyMapper, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	block = """
			// a comment - should be removed
			//also a comment
			# not a comment
			abc
			def
			"""

	simple.equal 240, doMap(MyMapper, import.meta.url, block), """
			# not a comment
			abc
			def
			"""

	tester.equal 246, block, """
			# not a comment
			abc
			def
			"""

	)()

# ---------------------------------------------------------------------------
# Test command handling

(() ->
	class MyMapper extends TreeWalker

		isCmd: (line) ->
			# --- line includes any indentation

			# --- commands only recognized if no indentation
			#     AND consist of '-' + one whitespace char + word
			if (lMatches = line.match(///^ - \s (\w+) $///))
				[_, cmd] = lMatches
				return {
					cmd
					argstr: ''
					prefix: ''
					}
			else
				return undef

		# .......................................................

		handleCmd: (cmd, argstr, prefix) ->

			return "COMMAND: #{cmd}"

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->
			return doMap(MyMapper, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	block = """
			# remove this

			abc
			- command
			def
			"""

	tester.equal 300, block, """
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

	class MyMapper extends TreeWalker

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

			return doMap(MyMapper, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	tester.equal 343, """
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

	class MyMapper extends TreeWalker

		# --- Remove blank lines PLUS the line following a blank line
		handleEmptyLine: (line) ->

			follow = @fetch()
			return undef    # remove empty lines

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyMapper, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	tester.equal 381, """
			abc

			def
			ghi
			""", """
			abc
			def
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

	tester.equal 408, """
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

			walker = new TreeWalker(undef, block)
			return walker.getAll()

	tester = new MyTester()

	tester.equal 437, """
			abc
				def
					ghi
			jkl
			""", taml("""
			---
			-
				level: 0
				lineNum: 1
				uobj: 'abc'
			-
				level: 1
				lineNum: 2
				uobj: 'def'
			-
				level: 2
				lineNum: 3
				uobj: 'ghi'
			-
				level: 0
				lineNum: 4
				uobj: 'jkl'
			""")

	)()

# ---------------------------------------------------------------------------

(() ->

	walker = new TreeWalker(undef, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	simple.equal 477, walker.peek(), {level:0, lineNum:1, item: 'if (x == 2)'}
	simple.equal 478, walker.get(),  {level:0, lineNum:1, item: 'if (x == 2)'}

	simple.equal 480, walker.peek(), {level:1, lineNum:2, item: 'doThis'}
	simple.equal 481, walker.get(),  {level:1, lineNum:2, item: 'doThis'}

	simple.equal 483, walker.peek(), {level:1, lineNum:3, item: 'doThat'}
	simple.equal 484, walker.get(),  {level:1, lineNum:3, item: 'doThat'}

	simple.equal 486, walker.peek(), {level:2, lineNum:4, item: 'then this'}
	simple.equal 487, walker.get(),  {level:2, lineNum:4, item: 'then this'}

	simple.equal 489, walker.peek(), {level:0, lineNum:5, item: 'while (x > 2)'}
	simple.equal 490, walker.get(),  {level:0, lineNum:5, item: 'while (x > 2)'}

	simple.equal 492, walker.peek(), {level:1, lineNum:6, item: '--x'}
	simple.equal 493, walker.get(),  {level:1, lineNum:6, item: '--x'}

	)()

# ---------------------------------------------------------------------------
# --- Test fetchBlockAtLevel()

(() ->

	walker = new TreeWalker(undef, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	simple.equal 511, walker.get(), {
		level: 0
		item:   'if (x == 2)'
		lineNum: 1
		}

	simple.equal 517, walker.fetchBlockAtLevel(1), """
			doThis
			doThat
				then this
			"""

	simple.equal 523, walker.get(), {
		level: 0
		item:   'while (x > 2)'
		lineNum: 5
		}

	simple.equal 529, walker.fetchBlockAtLevel(1), "--x"
	)()

# ---------------------------------------------------------------------------
# --- Test fetchBlockAtLevel() with mapping

(() ->

	class MyMapper extends TreeWalker

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

	walker = new MyMapper(undef, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	simple.equal 559, walker.get(), {
			level: 0
			item: {
				cmd: 'if'
				cond: '(x == 2)'
				}
			lineNum: 1
			}
	simple.equal 567, walker.fetchBlockAtLevel(1), """
			doThis
			doThat
				then this
			"""
	simple.equal 572, walker.get(), {
			level: 0
			item: {
				cmd: 'while',
				cond: '(x > 2)'
				}
			lineNum: 5
			}
	simple.equal 580, walker.fetchBlockAtLevel(1), "--x"
	simple.equal 581, walker.get(), undef
	)()

# ---------------------------------------------------------------------------
# --- Test TraceWalker

(() ->

	class WalkTester extends UnitTester

		transformValue: (block) ->

			walker = new TraceWalker(import.meta.url, block)
			return walker.walk()

	tester = new WalkTester()

	# ..........................................................

	tester.equal 600, """
			abc
			def
			""", """
			begin
			> 'abc'
			< 'abc'
			> 'def'
			< 'def'
			end
			"""

	tester.equal 612, """
			abc
				def
			""", """
			begin
			> 'abc'
			|.> 'def'
			|.< 'def'
			< 'abc'
			end
			"""

	# --- 2 indents is treated as an extension line
	tester.equal 625, """
			abc
					def
			""", """
			begin
			> 'abc˳def'
			< 'abc˳def'
			end
			"""

	tester.equal 635, """
			abc
				def
			ghi
			""", """
			begin
			> 'abc'
			|.> 'def'
			|.< 'def'
			< 'abc'
			> 'ghi'
			< 'ghi'
			end
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test HEREDOC

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	# ..........................................................

	tester = new MyTester()

	tester.equal 666, """
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

	tester.equal 679, """
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

	tester.equal 693, """
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

		debug "enter MyMapper.mapStr(#{level})", str
		lMatches = str.match(///^
				(\S+)     # the tag
				(?:
					\s+    # some whitespace
					(.*)   # everything else
					)?     # optional
				$///)
		assert defined(lMatches), "missing HTML tag"
		[_, tag, text] = lMatches
		hResult = {tag, level}
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

		debug "return from MyMapper.mapStr()", hResult
		return hResult

	# .......................................................

	visit: (uobj, level) ->

		lParts = [indented("<#{uobj.tag}>", level)]
		if nonEmpty(uobj.body)
			lParts.push indented(uobj.body, level+1)
		result = arrayToBlock(lParts)
		debug 'result', result
		return result

	# .......................................................

	endVisit: (uobj, level) ->

		return indented("</#{uobj.tag}>", level)

# ---------------------------------------------------------------------------

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(HtmlMapper, import.meta.url, block)

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 778, """
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

# --- TO DO: Add tests to show that comments/blank lines can be retained

# ---------------------------------------------------------------------------
# --- test #ifdef and #ifndef

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	tester = new MyTester()

	tester.equal 821, """
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
