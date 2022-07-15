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

	mapper = new Mapper(undef, [1, 2, 3])

	simple.equal 25, mapper.peek(), 1
	simple.equal 26, mapper.peek(), 1
	simple.falsy 27, mapper.eof()
	simple.equal 28, mapper.get(), 1
	simple.equal 29, mapper.get(), 2
	simple.equal 30, mapper.hSourceInfo.lineNum, 2

	simple.falsy 32, mapper.eof()
	simple.succeeds 33, () -> mapper.unfetch(5)
	simple.succeeds 34, () -> mapper.unfetch(6)
	simple.equal 35, mapper.get(), 6
	simple.equal 36, mapper.get(), 5
	simple.falsy 37, mapper.eof()

	simple.equal 39, mapper.get(), 3
	simple.equal 40, mapper.hSourceInfo.lineNum, 3
	simple.truthy 41, mapper.eof()
	simple.succeeds 42, () -> mapper.unfetch(13)
	simple.falsy 43, mapper.eof()
	simple.equal 44, mapper.get(), 13
	simple.truthy 45, mapper.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	mapper = new Mapper(undef, ['abc', 'def  ', 'ghi\t\t'])

	simple.equal 55, mapper.peek(), 'abc'
	simple.equal 56, mapper.peek(), 'abc'
	simple.falsy 57, mapper.eof()
	simple.equal 58, mapper.get(), 'abc'
	simple.equal 59, mapper.get(), 'def'
	simple.equal 60, mapper.get(), 'ghi'
	simple.equal 61, mapper.hSourceInfo.lineNum, 3
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

	simple.equal 77, mapper.fetch(), 'abc'

	# 'jkl' will be discarded
	simple.equal 80, mapper.fetchUntil('jkl'), ['def','ghi']

	simple.equal 82, mapper.fetch(), 'mno'
	simple.equal 83, mapper.hSourceInfo.lineNum, 5
	)()

# ---------------------------------------------------------------------------

(() ->

	# --- A generator is a function that, when you call it,
	#     it returns an iterator

	generator = () ->
		yield 1
		yield 2
		yield 3
		return

	# --- You can pass any iterator to the Mapper() constructor
	mapper = new Mapper(undef, generator())

	simple.equal 102, mapper.peek(), 1
	simple.equal 103, mapper.peek(), 1
	simple.falsy 104, mapper.eof()
	simple.equal 105, mapper.get(), 1
	simple.equal 106, mapper.get(), 2
	simple.equal 107, mapper.hSourceInfo.lineNum, 2

	simple.falsy 109, mapper.eof()
	simple.succeeds 110, () -> mapper.unfetch(5)
	simple.succeeds 111, () -> mapper.unfetch(6)
	simple.equal 112, mapper.get(), 6
	simple.equal 113, mapper.get(), 5
	simple.falsy 114, mapper.eof()

	simple.equal 116, mapper.get(), 3
	simple.truthy 117, mapper.eof()
	simple.succeeds 118, () -> mapper.unfetch(13)
	simple.falsy 119, mapper.eof()
	simple.equal 120, mapper.get(), 13
	simple.truthy 121, mapper.eof()
	simple.equal 122, mapper.hSourceInfo.lineNum, 3
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

	simple.equal 142, mapper.peek(), {a:1, b:2}
	simple.equal 143, mapper.peek(), {a:1, b:2}
	simple.falsy 144, mapper.eof()
	simple.equal 145, mapper.get(), {a:1, b:2}
	simple.equal 146, mapper.get(), ['a','b']

	simple.falsy 148, mapper.eof()
	simple.succeeds 149, () -> mapper.unfetch([])
	simple.succeeds 150, () -> mapper.unfetch({})
	simple.equal 151, mapper.get(), {}
	simple.equal 152, mapper.get(), []
	simple.falsy 153, mapper.eof()

	simple.equal 155, mapper.get(), 42
	simple.equal 156, mapper.get(), 'xyz'
	simple.truthy 157, mapper.eof()
	simple.succeeds 158, () -> mapper.unfetch(13)
	simple.falsy 159, mapper.eof()
	simple.equal 160, mapper.get(), 13
	simple.truthy 161, mapper.eof()
	simple.equal 162, mapper.hSourceInfo.lineNum, 4
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
			lAll = mapper.getAll()
			numLines = mapper.hSourceInfo.lineNum   # set variable numLines
			return arrayToBlock(lAll)

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
			def
			""", {prefix: '---'})

	simple.equal 211, mapper.getBlock(), """
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

	simple.equal 227, mapper.getBlock(), """
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
			lAll = mapper.getAll()
			numLines = mapper.hSourceInfo.lineNum   # set variable numLines
			return arrayToBlock(lAll)

	# ..........................................................

	tester = new MyTester()

	tester.equal 255, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	simple.equal 266, numLines, 2
	)()

# ---------------------------------------------------------------------------
# --- Test #include with __END__

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(import.meta.url, block)
			lAll = mapper.getAll()
			return arrayToBlock(lAll)

	# ..........................................................

	tester = new MyTester()

	tester.equal 286, """
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
			lAll = mapper.getAll()
			return arrayToBlock(lAll)

	# ..........................................................

	tester = new MyTester()

	tester.equal 315, """
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

	simple.equal 344, result, """
			# - test.txt
			abc
			The meaning of life is 42
			"""

	# --- Now, create a subclass that:
	#        1. removes empty lines
	#        2. recognizes '//' style comments and removes them
	#        3. implements a '#for <args>' cmd that outputs '{#for <args>}'

	class MyMapper extends Mapper
		handleEmptyLine: () -> return undef
		isComment: (line) -> return line.match(/\s*\/\//)
		handleComment: (line) -> return undef
		handleCmd: (cmd, argstr, prefix, h) ->
			if (cmd == 'for')
				return "#{prefix}{#for #{argstr}}"
			else
				return super(cmd, argstr, prefix, h)

	result = doMap(MyMapper, import.meta.url, """
			// test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			#for x in lItems
			""")

	simple.equal 344, result, """
			abc
			The meaning of life is 42
			{#for x in lItems}
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test map/unmap

(() ->

	class MyMapper extends Mapper
		handleEmptyLine: () -> return undef
		isComment: (line) -> return line.match(/\s*\/\//)
		handleComment: (line) -> return undef
		map: (line) ->
			return {
				line
				len: line.length
				}
		unmap: (obj) ->
			return "#{obj.len}"

	result = doMap(MyMapper, import.meta.url, """
			// test.txt

			abc

			defghi
			""")
	simple.equal 407, result, """
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

	simple.equal 226, mapper.peek(), 'if (x == 2)'
	simple.equal 227, mapper.get(),  'if (x == 2)'

	simple.equal 229, mapper.peek(), '\tdoThis'
	simple.equal 230, mapper.get(),  '\tdoThis'

	simple.equal 232, mapper.peek(), '\tdoThat'
	simple.equal 233, mapper.get(),  '\tdoThat'

	simple.equal 235, mapper.peek(), '\t\tthen this'
	simple.equal 236, mapper.get(),  '\t\tthen this'

	simple.equal 238, mapper.peek(), 'while (x > 2)'
	simple.equal 239, mapper.get(),  'while (x > 2)'

	simple.equal 241, mapper.peek(), '\t--x'
	simple.equal 242, mapper.get(),  '\t--x'

	)()
