# Mapper.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {undef, rtrim, replaceVars} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {
	arrayToBlock, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Mapper, map} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(undef, """
		line1
		line2
		line3
		""")

	simple.like 25, mapper.peek(), {str: 'line1', level: 0}
	simple.like 26, mapper.peek(), {str: 'line1', level: 0}
	simple.falsy 27, mapper.eof()
	simple.like 28, token0 = mapper.get(), {str: 'line1'}
	simple.like 29, token1 = mapper.get(), {str: 'line2'}
	simple.equal 30, mapper.lineNum, 2

	simple.falsy 32, mapper.eof()
	simple.succeeds 33, () -> mapper.unfetch(token1)
	simple.succeeds 34, () -> mapper.unfetch(token0)
	simple.like 35, mapper.get(), {str: 'line1'}
	simple.like 36, mapper.get(), {str: 'line2'}
	simple.falsy 37, mapper.eof()

	simple.like 39, token0 = mapper.get(), {str: 'line3'}
	simple.equal 40, mapper.lineNum, 3
	simple.truthy 41, mapper.eof()
	simple.succeeds 42, () -> mapper.unfetch(token0)
	simple.falsy 43, mapper.eof()
	simple.equal 44, mapper.get(), token0
	simple.truthy 45, mapper.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	mapper = new Mapper(undef, ['abc', 'def  ', 'ghi\t\t'])

	simple.like 55, mapper.peek(), {str: 'abc'}
	simple.like 56, mapper.peek(), {str: 'abc'}
	simple.falsy 57, mapper.eof()
	simple.like 58, mapper.get(), {str: 'abc'}
	simple.like 59, mapper.get(), {str: 'def'}
	simple.like 60, mapper.get(), {str: 'ghi'}
	simple.equal 61, mapper.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Special lines

(() ->
	mapper = new Mapper(undef, """
		line1
		# a comment
		line2

		line3
		""")
	simple.like 75, mapper.get(), {
		str: 'line1'
		level: 0
		lineNum: 1
		}
	simple.like 80, mapper.get(), {
		str: 'line2'
		level: 0
		lineNum: 3
		}
	simple.like 85, mapper.get(), {
		str: 'line3'
		level: 0
		lineNum: 5
		}
	simple.equal 90, mapper.get(), undef

	)()

# ---------------------------------------------------------------------------
# --- Test fetch(), fetchUntil()

(() ->

	mapper = new Mapper(undef, """
			abc
			def
			ghi
			jkl
			mno
			""")

	simple.like 107, mapper.fetch(), {str: 'abc'}

	# 'jkl' will be discarded
	simple.like 110, mapper.fetchUntil((hNode) -> (hNode.str == 'jkl')), [
		{str: 'def'}
		{str: 'ghi'}
		]

	simple.like 115, mapper.fetch(), {str: 'mno'}
	simple.equal 116, mapper.lineNum, 5
	)()

# ---------------------------------------------------------------------------

(() ->

	# --- A generator is a function that, when you call it,
	#     it returns an iterator

	generator = () ->
		yield 'line1'
		yield 'line2'
		yield 'line3'
		return

	# --- You can pass any iterator to the Mapper() constructor
	mapper = new Mapper(undef, generator())

	simple.like 135, mapper.peek(), {str: 'line1'}
	simple.like 136, mapper.peek(), {str: 'line1'}
	simple.falsy 137, mapper.eof()
	simple.like 138, token0 = mapper.get(), {str: 'line1'}
	simple.like 139, token1 = mapper.get(), {str: 'line2'}
	simple.equal 140, mapper.lineNum, 2

	simple.falsy 142, mapper.eof()
	simple.succeeds 143, () -> mapper.unfetch(token1)
	simple.succeeds 144, () -> mapper.unfetch(token0)
	simple.like 145, mapper.get(), {str: 'line1'}
	simple.like 146, mapper.get(), {str: 'line2'}
	simple.falsy 147, mapper.eof()

	simple.like 149, token3 = mapper.get(), {str: 'line3'}
	simple.truthy 150, mapper.eof()
	simple.succeeds 151, () -> mapper.unfetch(token3)
	simple.falsy 152, mapper.eof()
	simple.equal 153, mapper.get(), token3
	simple.truthy 154, mapper.eof()
	simple.equal 155, mapper.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# File title.md contains:
# title
# =====
# ---------------------------------------------------------------------------
# --- Test #include

(() ->

	numLines = undef

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(import.meta.url, block)
			block = mapper.getBlock()
			numLines = mapper.lineNum   # set variable numLines
			return block

	# ..........................................................

	tester = new MyTester()

	tester.equal 182, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	simple.equal 193, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(import.meta.url, """
			abc
				#include title.md
			def
			""")

	simple.equal 206, mapper.getBlock(), """
			abc
				title
				=====
			def
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test __END__

(() ->

	numLines = undef

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(import.meta.url, block)
			block = mapper.getBlock()
			numLines = mapper.lineNum   # set variable numLines
			return block

	# ..........................................................

	tester = new MyTester()

	tester.equal 234, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	simple.equal 245, numLines, 2
	)()

# ---------------------------------------------------------------------------
# --- Test #include with __END__

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(import.meta.url, block)
			block = mapper.getBlock()
			return block

	# ..........................................................

	tester = new MyTester()

	tester.equal 265, """
			abc
				#include ended.md
			def
			""", """
			abc
				ghi
			def
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test #define

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(import.meta.url, block)
			block = mapper.getBlock()
			return block

	# ..........................................................

	tester = new MyTester()

	tester.equal 294, """
			abc
			#define meaning 42
			meaning is __meaning__
			""", """
			abc
			meaning is 42
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test map()

(() ->

	# --- Usually:
	#        1. empty lines are removed
	#        2. '#' style comments are recognized and removed
	#        3. Only the #define command is interpreted

	result = map(import.meta.url, """
			# - test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			""", Mapper)

	simple.equal 323, result, """
			abc
			The meaning of life is 42
			"""

	# --- Now, create a subclass that:
	#        1. recognizes '//' style comments and removes them
	#        2. implements a '#for <args>' cmd that outputs '{#for <args>}'

	class MyMapper extends Mapper

		isComment: (hNode) -> return hNode.str.match(///^ \s* \/ \/ ///)

		mapCmd: (hNode) ->
			{cmd, argstr} = hNode.uobj
			if (cmd == 'for')
				return indented("{#for #{argstr}}", hNode.level, @oneIndent)
			else
				return super(hNode)

	result = map(import.meta.url, """
			// test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			#for x in lItems
			""", MyMapper)

	simple.equal 352, result, """
			abc
			The meaning of life is 42
			{#for x in lItems}
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test mapNonSpecial

(() ->

	class MyMapper extends Mapper

		isComment: (hNode) -> return hNode.str.match(/// \s* \/ \/ ///)

		mapEmptyLine: (hNode) -> return undef
		mapComment: (hNode) -> return undef
		mapNonSpecial: (hNode) ->
			return hNode.str.length.toString()

	result = map(import.meta.url, """
			// test.txt

			abc

			defghi
			""", MyMapper)
	simple.equal 381, result, """
			3
			6
			"""
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(undef, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	simple.like 400, mapper.peek(), {str: 'if (x == 2)', level: 0}
	simple.like 401, mapper.get(),  {str: 'if (x == 2)', level: 0}

	simple.like 403, mapper.peek(), {str: 'doThis', level: 1}
	simple.like 404, mapper.get(),  {str: 'doThis', level: 1}

	simple.like 406, mapper.peek(), {str: 'doThat', level: 1}
	simple.like 407, mapper.get(),  {str: 'doThat', level: 1}

	simple.like 409, mapper.peek(), {str: 'then this', level: 2}
	simple.like 410, mapper.get(),  {str: 'then this', level: 2}

	simple.like 412, mapper.peek(), {str: 'while (x > 2)', level: 0}
	simple.like 413, mapper.get(),  {str: 'while (x > 2)', level: 0}

	simple.like 415, mapper.peek(), {str: '--x', level: 1}
	simple.like 416, mapper.get(),  {str: '--x', level: 1}

	)()
