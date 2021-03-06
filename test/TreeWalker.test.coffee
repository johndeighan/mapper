# TreeWalker.test.coffee

import {UnitTester, UnitTesterNorm, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, OL, defined,
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

###
	class TreeWalker should handle the following:
		- remove empty lines and comments
		- extension lines
		- can override @map() - used in @getAll()
		- call @walk() to walk the tree
		- can override beginWalk(), visit(), endVisit(), endWalk()
###

# ---------------------------------------------------------------------------
# --- Test TreeWalker.get() with special lines

(() ->
	walker = new TreeWalker(undef, """
		line1
		# a comment
		line2

		line3
		""")
	simple.like 44, walker.get(), {
		str: 'line1'
		level: 0
		lineNum: 1
		}
	simple.like 49, walker.get(), {
		str: 'line2'
		level: 0
		lineNum: 3
		}
	simple.like 54, walker.get(), {
		str: 'line3'
		level: 0
		lineNum: 5
		}
	simple.equal 59, walker.get(), undef

	)()

# ---------------------------------------------------------------------------
# Test TreeWalker.get()

(() ->
	walker = new TreeWalker(import.meta.url, """
			# --- a comment

			abc
				def
					ghi
			""")

	simple.like 75, walker.get(), {
		str:  'abc'
		level: 0
		}
	simple.like 79, walker.get(), {
		str:  'def'
		level: 1
		}
	simple.like 83, walker.get(), {
		str:  'ghi'
		level: 2
		}
	simple.equal 87, walker.get(), undef
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

	simple.like 104, walker.get(), {
		str: 'abc def'
		level: 0
		}
	simple.like 108, walker.get(), {
		str: 'ghi'
		level: 1
		}
	simple.equal 112, walker.get(), undef
	)()

# ---------------------------------------------------------------------------
# __END__ only works with no identation

(() ->
	simple.fails 119, () -> doMap(TreeWalker, import.meta.url, """
			abc
					def
				ghi
				__END__
					ghi
			""")
	)()

# ---------------------------------------------------------------------------

(() ->

	class Tester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	tester = new Tester()

	# ---------------------------------------------------------------------------
	# --- Test basic reading till EOF

	tester.equal 143, """
			abc
			def
			""", """
			abc
			def
			"""

	tester.equal 151, """
			abc

			def
			""", """
			abc
			def
			"""

	tester.equal 160, """
		# --- a comment
		p
			margin: 0
			span
				color: red
		""", """
		p
			margin: 0
			span
				color: red
		"""

	)()

# ---------------------------------------------------------------------------
# Test empty line handling

(() ->
	class MyWalker extends TreeWalker

		# --- This removes blank lines
		mapEmptyLine: () ->

			debug "in MyWalker.mapEmptyLine()"
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

	simple.equal 205, doMap(MyWalker, import.meta.url, block), """
			abc
			def
			"""

	tester.equal 210, block, """
			abc
			def
			"""

	)()

# ---------------------------------------------------------------------------
# Test comment handling

(() ->
	class MyWalker extends TreeWalker

		isComment: (hNode) ->

			# --- comments start with //
			return hNode.str.match(///^ \/ \/ ///)

		mapComment: (hNode) ->

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

	simple.equal 253, doMap(MyWalker, import.meta.url, block), """
			# not a comment
			abc
			def
			"""

	tester.equal 259, block, """
			# not a comment
			abc
			def
			"""

	)()

# ---------------------------------------------------------------------------
# Test command handling

(() ->
	class MyWalker extends TreeWalker

		isCmd: (hNode) ->
			# --- commands consist of '-' + one whitespace char + word
			if (lMatches = hNode.str.match(///^ - \s (\w+) $///))
				hNode.uobj = {
					cmd: lMatches[1]
					argstr: ''
					}
				return true
			else
				return false

		# .......................................................

		mapCmd: (hNode) ->

			# --- NOTE: this disables handling all commands,
			#           i.e. #define, etc.
			# --- Returning any non-undef value prevents discarding hNode
			#     and sets key uobj to the returned value
			return hNode.uobj

		# .......................................................

		visitCmd: (hNode) ->

			debug "enter MyWalker.visitCmd()"
			result = "COMMAND: #{hNode.uobj.cmd}"
			debug "return from MyWalker.visitCmd()", result
			return result

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->
			return doMap(MyWalker, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	block = """
			# remove this

			abc
			- command
			def
			"""

	tester.equal 322, block, """
			abc
			COMMAND: command
			def
			"""

	)()

# ---------------------------------------------------------------------------
# try retaining indentation for mapped lines

(()->

	# --- NOTE: map() returns anything,
	#           or undef to ignore the line

	class MyWalker extends TreeWalker

		# --- This maps all non-empty lines to the string 'x'
		#     and removes all empty lines
		map: (hNode) ->

			debug "enter map()", hNode
			{str, level} = hNode
			if isEmpty(str)
				debug "return undef from map() - empty line"
				return undef
			else
				debug "return 'x' from map()"
				return indented('x', level, @oneIndent)

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyWalker, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	tester.equal 365, """
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
		mapEmptyLine: (hNode) ->

			follow = @fetch()
			return undef    # remove empty lines

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(MyWalker, import.meta.url, block)

	tester = new MyTester()

	# ..........................................................

	tester.equal 403, """
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

	tester.equal 429, """
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

	tester.like 458, """
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

	simple.like 494, walker.peek(), {level:0, str: 'if (x == 2)'}
	simple.like 495, walker.get(),  {level:0, str: 'if (x == 2)'}

	simple.like 497, walker.peek(), {level:1, str: 'doThis'}
	simple.like 498, walker.get(),  {level:1, str: 'doThis'}

	simple.like 500, walker.peek(), {level:1, str: 'doThat'}
	simple.like 501, walker.get(),  {level:1, str: 'doThat'}

	simple.like 503, walker.peek(), {level:2, str: 'then this'}
	simple.like 504, walker.get(),  {level:2, str: 'then this'}

	simple.like 506, walker.peek(), {level:0, str: 'while (x > 2)'}
	simple.like 507, walker.get(),  {level:0, str: 'while (x > 2)'}

	simple.like 509, walker.peek(), {level:1, str: '--x'}
	simple.like 510, walker.get(),  {level:1, str: '--x'}

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

	simple.like 528, walker.get(), {
		level: 0
		str:   'if (x == 2)'
		}

	simple.equal 533, walker.fetchBlockAtLevel(1), """
			doThis
			doThat
				then this
			"""

	simple.like 539, walker.get(), {
		level: 0
		str:   'while (x > 2)'
		}

	simple.equal 544, walker.fetchBlockAtLevel(1), "--x"
	)()

# ---------------------------------------------------------------------------
# --- Test fetchBlockAtLevel() with mapping

(() ->

	class MyWalker extends TreeWalker

		map: (hNode) ->
			{str, level} = hNode
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

	simple.like 575, walker.get(), {
			level: 0
			str: 'if (x == 2)'
			uobj: {
				cmd: 'if'
				cond: '(x == 2)'
				}
			}
	simple.equal 583, walker.fetchBlockAtLevel(1), """
			doThis
			doThat
				then this
			"""
	simple.like 588, walker.get(), {
			level: 0
			str: 'while (x > 2)'
			uobj: {
				cmd: 'while',
				cond: '(x > 2)'
				}
			}
	simple.equal 596, walker.fetchBlockAtLevel(1), "--x"
	simple.equal 597, walker.get(), undef
	)()

# ---------------------------------------------------------------------------
# --- Test HEREDOC

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	# ..........................................................

	tester = new MyTester()

	tester.equal 615, """
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

	tester.equal 628, """
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

	tester.equal 642, """
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

	map: (hNode) ->

		debug "enter MyWalker.map()", hNode
		{str, level} = hNode
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

		debug "return from MyWalker.map()", hResult
		return hResult

	# .......................................................

	visit: (hNode, hUser, lStack) ->

		{str, uobj, level, type} = hNode
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

	endVisit: (hNode, hUser, lStack) ->

		{uobj, level, type} = hNode
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

	tester.equal 743, """
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

# ---------------------------------------------------------------------------
# --- test #ifdef and #ifndef

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return doMap(TreeWalker, import.meta.url, block)

	tester = new MyTester()

	tester.equal 784, """
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
