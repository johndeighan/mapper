# Mapper.test.coffee

import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {undef, rtrim, replaceVars} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {
	arrayToBlock, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Mapper, doMap} from '@jdeighan/mapper'

simple = new UnitTester()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(undef, """
		line1
		line2
		line3
		""")

	simple.like 26, mapper.peek(), {str: 'line1', level: 0}
	simple.like 27, mapper.peek(), {str: 'line1', level: 0}
	simple.falsy 28, mapper.eof()
	simple.like 29, token0 = mapper.get(), {str: 'line1'}
	simple.like 30, token1 = mapper.get(), {str: 'line2'}
	simple.equal 31, mapper.lineNum, 2

	simple.falsy 33, mapper.eof()
	simple.succeeds 34, () -> mapper.unfetch(token1)
	simple.succeeds 35, () -> mapper.unfetch(token0)
	simple.like 36, mapper.get(), {str: 'line1'}
	simple.like 37, mapper.get(), {str: 'line2'}
	simple.falsy 38, mapper.eof()

	simple.like 40, token0 = mapper.get(), {str: 'line3'}
	simple.equal 41, mapper.lineNum, 3
	simple.truthy 42, mapper.eof()
	simple.succeeds 43, () -> mapper.unfetch(token0)
	simple.falsy 44, mapper.eof()
	simple.equal 45, mapper.get(), token0
	simple.truthy 46, mapper.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	mapper = new Mapper(undef, ['abc', 'def  ', 'ghi\t\t'])

	simple.like 56, mapper.peek(), {str: 'abc'}
	simple.like 57, mapper.peek(), {str: 'abc'}
	simple.falsy 58, mapper.eof()
	simple.like 59, mapper.get(), {str: 'abc'}
	simple.like 60, mapper.get(), {str: 'def'}
	simple.like 61, mapper.get(), {str: 'ghi'}
	simple.equal 62, mapper.lineNum, 3
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
	simple.like 76, mapper.get(), {
		str: 'line1'
		level: 0
		lineNum: 1
		}
	simple.like 81, mapper.get(), {
		str: 'line2'
		level: 0
		lineNum: 3
		}
	simple.like 92, mapper.get(), {
		str: 'line3'
		level: 0
		lineNum: 5
		}
	simple.equal 97, mapper.get(), undef

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

	simple.like 114, mapper.fetch(), {str: 'abc'}

	# 'jkl' will be discarded
	simple.like 117, mapper.fetchUntil('jkl'), [
		{str: 'def'}
		{str: 'ghi'}
		]

	simple.like 122, mapper.fetch(), {str: 'mno'}
	simple.equal 123, mapper.lineNum, 5
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

	simple.like 142, mapper.peek(), {str: 'line1'}
	simple.like 143, mapper.peek(), {str: 'line1'}
	simple.falsy 144, mapper.eof()
	simple.like 145, token0 = mapper.get(), {str: 'line1'}
	simple.like 146, token1 = mapper.get(), {str: 'line2'}
	simple.equal 147, mapper.lineNum, 2

	simple.falsy 149, mapper.eof()
	simple.succeeds 150, () -> mapper.unfetch(token1)
	simple.succeeds 151, () -> mapper.unfetch(token0)
	simple.like 152, mapper.get(), {str: 'line1'}
	simple.like 153, mapper.get(), {str: 'line2'}
	simple.falsy 154, mapper.eof()

	simple.like 156, token3 = mapper.get(), {str: 'line3'}
	simple.truthy 157, mapper.eof()
	simple.succeeds 158, () -> mapper.unfetch(token3)
	simple.falsy 159, mapper.eof()
	simple.equal 160, mapper.get(), token3
	simple.truthy 161, mapper.eof()
	simple.equal 162, mapper.lineNum, 3
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

	tester.equal 189, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	simple.equal 200, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(import.meta.url, """
			abc
				#include title.md
			def
			""")

	simple.equal 213, mapper.getBlock(), """
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

	tester.equal 241, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	simple.equal 252, numLines, 2
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

	tester.equal 272, """
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

	tester.equal 301, """
			abc
			#define meaning 42
			meaning is __meaning__
			""", """
			abc
			meaning is 42
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test doMap()

(() ->

	# --- Usually:
	#        1. empty lines are removed
	#        2. '#' style comments are recognized and removed
	#        3. Only the #define command is interpreted

	result = doMap(Mapper, import.meta.url, """
			# - test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			""")

	simple.equal 330, result, """
			abc
			The meaning of life is 42
			"""

	# --- Now, create a subclass that:
	#        1. recognizes '//' style comments and removes them
	#        2. implements a '#for <args>' cmd that outputs '{#for <args>}'

	class MyMapper extends Mapper
		isComment: (hNode) -> return hNode.str.match(///^ \s* \/ \/ ///)

		mapCmd: (hNode) ->
			{cmd, argstr} = hNode
			if (cmd == 'for')
				return "#{hNode.getIndent()}{#for #{argstr}}"
			else
				return super(hNode)

	result = doMap(MyMapper, import.meta.url, """
			// test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			#for x in lItems
			""")

	simple.equal 358, result, """
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

	result = doMap(MyMapper, import.meta.url, """
			// test.txt

			abc

			defghi
			""")
	simple.equal 387, result, """
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

	simple.like 406, mapper.peek(), {str: 'if (x == 2)', level: 0}
	simple.like 407, mapper.get(),  {str: 'if (x == 2)', level: 0}

	simple.like 409, mapper.peek(), {str: 'doThis', level: 1}
	simple.like 410, mapper.get(),  {str: 'doThis', level: 1}

	simple.like 412, mapper.peek(), {str: 'doThat', level: 1}
	simple.like 413, mapper.get(),  {str: 'doThat', level: 1}

	simple.like 415, mapper.peek(), {str: 'then this', level: 2}
	simple.like 416, mapper.get(),  {str: 'then this', level: 2}

	simple.like 418, mapper.peek(), {str: 'while (x > 2)', level: 0}
	simple.like 419, mapper.get(),  {str: 'while (x > 2)', level: 0}

	simple.like 421, mapper.peek(), {str: '--x', level: 1}
	simple.like 422, mapper.get(),  {str: '--x', level: 1}

	)()
