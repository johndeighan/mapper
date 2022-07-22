# Mapper.test.coffee

import assert from 'assert'

import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {
	undef, error, warn, rtrim, replaceVars,
	} from '@jdeighan/coffee-utils'
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

	simple.like 29, mapper.peek(), {line: 'line1'}
	simple.like 30, mapper.peek(), {line: 'line1'}
	simple.falsy 31, mapper.eof()
	simple.like 32, token0 = mapper.get(), {line: 'line1'}
	simple.like 33, token1 = mapper.get(), {line: 'line2'}
	simple.equal 34, mapper.lineNum, 2

	simple.falsy 36, mapper.eof()
	simple.succeeds 37, () -> mapper.unfetch(token1)
	simple.succeeds 38, () -> mapper.unfetch(token0)
	simple.like 39, mapper.get(), {line: 'line6'}
	simple.like 40, mapper.get(), {line: 'line5'}
	simple.falsy 41, mapper.eof()

	simple.like 43, token0 = mapper.get(), {line: 'line3'}
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

	simple.like 59, mapper.peek(), {line: 'abc'}
	simple.like 60, mapper.peek(), {line: 'abc'}
	simple.falsy 61, mapper.eof()
	simple.like 62, mapper.get(), {line: 'abc'}
	simple.like 63, mapper.get(), {line: 'def'}
	simple.like 64, mapper.get(), {line: 'ghi'}
	simple.equal 65, mapper.lineNum, 3
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

	simple.like 81, mapper.fetch(), {line: 'abc'}

	# 'jkl' will be discarded
	simple.like 84, mapper.fetchUntil('jkl'), [
		{line: 'def'}
		{line: 'ghi'}
		]

	simple.like 89, mapper.fetch(), {line: 'mno'}
	simple.equal 90, mapper.lineNum, 5
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

	simple.like 109, mapper.peek(), {line: 'line1'}
	simple.like 110, mapper.peek(), {line: 'line1'}
	simple.falsy 111, mapper.eof()
	simple.like 112, token0 = mapper.get(), {line: 'line1'}
	simple.like 113, token1 = mapper.get(), {line: 'line2'}
	simple.equal 114, mapper.lineNum, 2

	simple.falsy 116, mapper.eof()
	simple.succeeds 117, () -> mapper.unfetch(token1)
	simple.succeeds 118, () -> mapper.unfetch(token0)
	simple.like 119, mapper.get(), {line: 'line1'}
	simple.like 120, mapper.get(), {line: 'line2'}
	simple.falsy 121, mapper.eof()

	simple.like 123, token13 = mapper.get(), {line: 'line3'}
	simple.truthy 124, mapper.eof()
	simple.succeeds 125, () -> mapper.unfetch(token13)
	simple.falsy 126, mapper.eof()
	simple.equal 127, mapper.get(), token13
	simple.truthy 128, mapper.eof()
	simple.equal 129, mapper.lineNum, 3
	)()

# ---------------------------------------------------------------------------

(() ->
	# --- Mapper should work with any types of objects

	# --- A generator is a function that, when you call it,
	#     it returns an iterator

	lItems = [
		{a:1, b:2}
		['a','b']
		42
		'xyz'
		]

	mapper = new Mapper(undef, lItems)

	simple.like 149, mapper.peek(), {line: {a:1, b:2}}
	simple.like 150, mapper.peek(), {line: {a:1, b:2}}
	simple.falsy 151, mapper.eof()
	simple.like 152, token0 = mapper.get(), {line: {a:1, b:2}}
	simple.like 153, token1 = mapper.get(), {line: ['a','b']}

	simple.falsy 155, mapper.eof()
	simple.succeeds 156, () -> mapper.unfetch(token1)
	simple.succeeds 157, () -> mapper.unfetch(token0)
	simple.equal 158, mapper.get(), token0
	simple.equal 159, mapper.get(), token1
	simple.falsy 160, mapper.eof()

	simple.like 162, mapper.get(), {line: 42}
	simple.like 163, token2 = mapper.get(), {line: 'xyz'}
	simple.truthy 164, mapper.eof()
	simple.succeeds 165, () -> mapper.unfetch(token2)
	simple.falsy 166, mapper.eof()
	simple.equal 167, mapper.get(), token2
	simple.truthy 168, mapper.eof()
	simple.equal 169, mapper.lineNum, 4
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

	tester.equal 196, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	simple.equal 207, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->
	mapper = new Mapper(import.meta.url, """
			abc
			def
			""", {prefix: '---'})

	simple.equal 218, mapper.getBlock(), """
			---abc
			---def
			"""
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(import.meta.url, """
			abc
				#include title.md
			def
			""")

	simple.equal 234, mapper.getBlock(), """
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

	tester.equal 262, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	simple.equal 273, numLines, 2
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

	tester.equal 293, """
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

	tester.equal 322, """
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

	simple.equal 351, result, """
			# - test.txt
			abc
			The meaning of life is 42
			"""

	# --- Now, create a subclass that:
	#        1. removes empty lines
	#        2. recognizes '//' style comments and removes them
	#        3. implements a '#for <args>' cmd that outputs '{#for <args>}'

	class MyMapper extends Mapper
		isComment: (line, hLine) -> return line.match(///^ \s* \/ \/ ///)

		handleEmptyLine: (hLine) -> return undef
		handleComment: (hLine) -> return undef
		handleCmd: (hLine) ->
			{cmd, argstr, prefix} = hLine
			if (cmd == 'for')
				return "#{prefix}{#for #{argstr}}"
			else
				return super(hLine)

	result = doMap(MyMapper, import.meta.url, """
			// test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			#for x in lItems
			""")

	simple.equal 383, result, """
			abc
			The meaning of life is 42
			{#for x in lItems}
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test map

(() ->

	class MyMapper extends Mapper

		isComment: (line, hLine) -> return line.match(/// \s* \/ \/ ///)

		handleEmptyLine: (hLine) -> return undef
		handleComment: (hLine) -> return undef
		map: (hLine) ->
			return hLine.line.length.toString()

	result = doMap(MyMapper, import.meta.url, """
			// test.txt

			abc

			defghi
			""")
	simple.equal 412, result, """
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

	simple.like 431, mapper.peek(), {line: 'if (x == 2)'}
	simple.like 432, mapper.get(),  {line: 'if (x == 2)'}

	simple.like 434, mapper.peek(), {line: '\tdoThis'}
	simple.like 435, mapper.get(),  {line: '\tdoThis'}

	simple.like 437, mapper.peek(), {line: '\tdoThat'}
	simple.like 438, mapper.get(),  {line: '\tdoThat'}

	simple.like 440, mapper.peek(), {line: '\t\tthen this'}
	simple.like 441, mapper.get(),  {line: '\t\tthen this'}

	simple.like 443, mapper.peek(), {line: 'while (x > 2)'}
	simple.like 444, mapper.get(),  {line: 'while (x > 2)'}

	simple.like 446, mapper.peek(), {line: '\t--x'}
	simple.like 447, mapper.get(),  {line: '\t--x'}

	)()
