# Getter.test.coffee

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

import {Getter} from '@jdeighan/mapper/getter'

simple = new UnitTester()

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter(undef, [1, 2, 3])

	simple.equal 25, getter.peek(), 1
	simple.equal 26, getter.peek(), 1
	simple.falsy 27, getter.eof()
	simple.equal 28, getter.get(), 1
	simple.equal 29, getter.get(), 2
	simple.equal 30, getter.hSourceInfo.lineNum, 2

	simple.falsy 32, getter.eof()
	simple.succeeds 33, () -> getter.unfetch(5)
	simple.succeeds 34, () -> getter.unfetch(6)
	simple.equal 35, getter.get(), 6
	simple.equal 36, getter.get(), 5
	simple.falsy 37, getter.eof()

	simple.equal 39, getter.get(), 3
	simple.equal 40, getter.hSourceInfo.lineNum, 3
	simple.truthy 41, getter.eof()
	simple.succeeds 42, () -> getter.unfetch(13)
	simple.falsy 43, getter.eof()
	simple.equal 44, getter.get(), 13
	simple.truthy 45, getter.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	getter = new Getter(undef, ['abc', 'def  ', 'ghi\t\t'])

	simple.equal 55, getter.peek(), 'abc'
	simple.equal 56, getter.peek(), 'abc'
	simple.falsy 57, getter.eof()
	simple.equal 58, getter.get(), 'abc'
	simple.equal 59, getter.get(), 'def'
	simple.equal 60, getter.get(), 'ghi'
	simple.equal 61, getter.hSourceInfo.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Test fetch(), fetchUntil()

(() ->

	getter = new Getter(undef, """
			abc
			def
			ghi
			jkl
			mno
			""")

	simple.equal 77, getter.fetch(), 'abc'

	# 'jkl' will be discarded
	simple.equal 80, getter.fetchUntil('jkl'), ['def','ghi']

	simple.equal 82, getter.fetch(), 'mno'
	simple.equal 83, getter.hSourceInfo.lineNum, 5
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

	# --- You can pass any iterator to the Getter() constructor
	getter = new Getter(undef, generator())

	simple.equal 102, getter.peek(), 1
	simple.equal 103, getter.peek(), 1
	simple.falsy 104, getter.eof()
	simple.equal 105, getter.get(), 1
	simple.equal 106, getter.get(), 2
	simple.equal 107, getter.hSourceInfo.lineNum, 2

	simple.falsy 109, getter.eof()
	simple.succeeds 110, () -> getter.unfetch(5)
	simple.succeeds 111, () -> getter.unfetch(6)
	simple.equal 112, getter.get(), 6
	simple.equal 113, getter.get(), 5
	simple.falsy 114, getter.eof()

	simple.equal 116, getter.get(), 3
	simple.truthy 117, getter.eof()
	simple.succeeds 118, () -> getter.unfetch(13)
	simple.falsy 119, getter.eof()
	simple.equal 120, getter.get(), 13
	simple.truthy 121, getter.eof()
	simple.equal 122, getter.hSourceInfo.lineNum, 3
	)()

# ---------------------------------------------------------------------------

(() ->
	# --- Getter should work with any types of objects

	# --- A generator is a function that, when you call it,
	#     it returns an iterator

	lItems = [
		{a:1, b:2}
		['a','b']
		42
		'xyz'
		]

	getter = new Getter(undef, lItems)

	simple.equal 142, getter.peek(), {a:1, b:2}
	simple.equal 143, getter.peek(), {a:1, b:2}
	simple.falsy 144, getter.eof()
	simple.equal 145, getter.get(), {a:1, b:2}
	simple.equal 146, getter.get(), ['a','b']

	simple.falsy 148, getter.eof()
	simple.succeeds 149, () -> getter.unfetch([])
	simple.succeeds 150, () -> getter.unfetch({})
	simple.equal 151, getter.get(), {}
	simple.equal 152, getter.get(), []
	simple.falsy 153, getter.eof()

	simple.equal 155, getter.get(), 42
	simple.equal 156, getter.get(), 'xyz'
	simple.truthy 157, getter.eof()
	simple.succeeds 158, () -> getter.unfetch(13)
	simple.falsy 159, getter.eof()
	simple.equal 160, getter.get(), 13
	simple.truthy 161, getter.eof()
	simple.equal 162, getter.hSourceInfo.lineNum, 4
	)()

# ---------------------------------------------------------------------------

(() ->
	getter = new Getter(import.meta.url, """
			abc
			def
			""", {prefix: '---'})

	simple.equal 173, getter.getBlock(), """
			---abc
			---def
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test __END__

(() ->

	numLines = undef

	class MyTester extends UnitTester

		transformValue: (block) ->

			getter = new Getter(import.meta.url, block)
			lAll = getter.getAll()
			numLines = getter.hSourceInfo.lineNum   # set variable numLines
			return arrayToBlock(lAll)

	# ..........................................................

	tester = new MyTester()

	tester.equal 199, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	simple.equal 210, numLines, 2
	)()

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter(undef, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	simple.equal 226, getter.peek(), 'if (x == 2)'
	simple.equal 227, getter.get(),  'if (x == 2)'

	simple.equal 229, getter.peek(), '\tdoThis'
	simple.equal 230, getter.get(),  '\tdoThis'

	simple.equal 232, getter.peek(), '\tdoThat'
	simple.equal 233, getter.get(),  '\tdoThat'

	simple.equal 235, getter.peek(), '\t\tthen this'
	simple.equal 236, getter.get(),  '\t\tthen this'

	simple.equal 238, getter.peek(), 'while (x > 2)'
	simple.equal 239, getter.get(),  'while (x > 2)'

	simple.equal 241, getter.peek(), '\t--x'
	simple.equal 242, getter.get(),  '\t--x'

	)()
