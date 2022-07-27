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

	simple.like 29, mapper.peek(), {str: 'line1'}
	simple.like 30, mapper.peek(), {str: 'line1'}
	simple.falsy 31, mapper.eof()
	simple.like 32, token0 = mapper.get(), {str: 'line1'}
	simple.like 33, token1 = mapper.get(), {str: 'line2'}
	simple.equal 34, mapper.lineNum, 2

	simple.falsy 36, mapper.eof()
	simple.succeeds 37, () -> mapper.unfetch(token1)
	simple.succeeds 38, () -> mapper.unfetch(token0)
	simple.like 39, mapper.get(), {str: 'line6'}
	simple.like 40, mapper.get(), {str: 'line5'}
	simple.falsy 41, mapper.eof()

	simple.like 43, token0 = mapper.get(), {str: 'line3'}
	simple.equal 44, mapper.lineNum, 3
	simple.truthy 45, mapper.eof()
	simple.succeeds 46, () -> mapper.unfetch(token0)
	simple.falsy 47, mapper.eof()
	simple.equal 48, mapper.get(), token0
	simple.truthy 49, mapper.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	mapper = new Mapper(undef, ['abc', 'def  ', 'ghi\t\t'])

	simple.like 59, mapper.peek(), {str: 'abc'}
	simple.like 60, mapper.peek(), {str: 'abc'}
	simple.falsy 61, mapper.eof()
	simple.like 62, mapper.get(), {str: 'abc'}
	simple.like 63, mapper.get(), {str: 'def'}
	simple.like 64, mapper.get(), {str: 'ghi'}
	simple.equal 65, mapper.lineNum, 3
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
	simple.like 79, mapper.get(), {
		str: 'line1'
		level: 0
		lineNum: 1
		}
	simple.like 84, mapper.get(), {
		str: '# a comment'
		level: 0
		lineNum: 1
		type: 'comment'
		comment: 'a comment'
		}
	simple.like 91, mapper.get(), {
		str: 'line2'
		level: 0
		lineNum: 3
		}
	simple.like 96, mapper.get(), {
		str: ''
		level: 0
		lineNum: 4
		type: 'empty'
		}
	simple.like 102, mapper.get(), {
		str: 'line3'
		level: 0
		lineNum: 5
		}
	simple.equal 107, mapper.get(), undef

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

	simple.like 124, mapper.fetch(), {str: 'abc'}

	# 'jkl' will be discarded
	simple.like 127, mapper.fetchUntil('jkl'), [
		{str: 'def'}
		{str: 'ghi'}
		]

	simple.like 132, mapper.fetch(), {str: 'mno'}
	simple.equal 133, mapper.lineNum, 5
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

	simple.like 152, mapper.peek(), {str: 'line1'}
	simple.like 153, mapper.peek(), {str: 'line1'}
	simple.falsy 154, mapper.eof()
	simple.like 155, token0 = mapper.get(), {str: 'line1'}
	simple.like 156, token1 = mapper.get(), {str: 'line2'}
	simple.equal 157, mapper.lineNum, 2

	simple.falsy 159, mapper.eof()
	simple.succeeds 160, () -> mapper.unfetch(token1)
	simple.succeeds 161, () -> mapper.unfetch(token0)
	simple.like 162, mapper.get(), {str: 'line1'}
	simple.like 163, mapper.get(), {str: 'line2'}
	simple.falsy 164, mapper.eof()

	simple.like 166, token3 = mapper.get(), {str: 'line3'}
	simple.truthy 167, mapper.eof()
	simple.succeeds 168, () -> mapper.unfetch(token3)
	simple.falsy 169, mapper.eof()
	simple.equal 170, mapper.get(), token3
	simple.truthy 171, mapper.eof()
	simple.equal 172, mapper.lineNum, 3
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

	tester.equal 199, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	simple.equal 210, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(import.meta.url, """
			abc
				#include title.md
			def
			""")

	simple.equal 223, mapper.getBlock(), """
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

	tester.equal 251, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	simple.equal 262, numLines, 2
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

	tester.equal 282, """
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

	tester.equal 311, """
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

	simple.equal 340, result, """
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

	simple.equal 368, result, """
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
	simple.equal 397, result, """
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

	simple.like 416, mapper.peek(), {str: 'if (x == 2)'}
	simple.like 417, mapper.get(),  {str: 'if (x == 2)'}

	simple.like 419, mapper.peek(), {str: '\tdoThis'}
	simple.like 420, mapper.get(),  {str: '\tdoThis'}

	simple.like 422, mapper.peek(), {str: '\tdoThat'}
	simple.like 423, mapper.get(),  {str: '\tdoThat'}

	simple.like 425, mapper.peek(), {str: '\t\tthen this'}
	simple.like 426, mapper.get(),  {str: '\t\tthen this'}

	simple.like 428, mapper.peek(), {str: 'while (x > 2)'}
	simple.like 429, mapper.get(),  {str: 'while (x > 2)'}

	simple.like 431, mapper.peek(), {str: '\t--x'}
	simple.like 432, mapper.get(),  {str: '\t--x'}

	)()
