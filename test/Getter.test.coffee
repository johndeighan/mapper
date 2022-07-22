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
import {phStr, phReplace} from '@jdeighan/coffee-utils/placeholders'

import {Getter} from '@jdeighan/mapper/getter'

simple = new UnitTester()

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter(undef, ['line1', 'line2', 'line3'])

	simple.like 26, getter.peek(), {line: 'line1'}
	simple.like 27, getter.peek(), {line: 'line1'}
	simple.falsy 28, getter.eof()
	simple.like 29, getter.get(), {line: 'line1'}
	simple.like 30, getter.get(), {line: 'line2'}
	simple.equal 31, getter.lineNum, 2

	simple.falsy 33, getter.eof()
	simple.succeeds 34, () -> getter.unfetch({
		line: 'line5'
		str: 'line5'
		prefix: ''
		})
	simple.succeeds 35, () -> getter.unfetch({
		line: 'line6'
		str: 'line6'
		prefix: ''
		})
	simple.like 36, getter.get(), {line: 'line6'}
	simple.like 37, getter.get(), {line: 'line5'}
	simple.falsy 38, getter.eof()

	simple.like 40, getter.get(), {line: 'line3'}
	simple.equal 41, getter.lineNum, 3
	simple.truthy 42, getter.eof()
	simple.succeeds 43, () -> getter.unfetch({
		line: 'line13'
		str: 'line13'
		prefix: ''
		})
	simple.falsy 44, getter.eof()
	simple.like 45, getter.get(), {line: 'line13'}
	simple.truthy 46, getter.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	getter = new Getter(undef, ['abc', 'def  ', 'ghi\t\t'])

	simple.like 56, getter.peek(), {line: 'abc'}
	simple.like 57, getter.peek(), {line: 'abc'}
	simple.falsy 58, getter.eof()
	simple.like 59, getter.get(), {line: 'abc'}
	simple.like 60, getter.get(), {line: 'def'}
	simple.like 61, getter.get(), {line: 'ghi'}
	simple.equal 62, getter.lineNum, 3
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

	simple.like 78, getter.fetch(), {line: 'abc'}

	# 'jkl' will be discarded
	simple.like 81, getter.fetchUntil('jkl'), [
		{line: 'def'}
		{line: 'ghi'}
		]

	simple.like 86, getter.fetch(), {line: 'mno'}
	simple.equal 87, getter.lineNum, 5
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

	# --- You can pass any iterator to the Getter() constructor
	getter = new Getter(undef, generator())

	simple.like 106, getter.peek(), {line: 'line1'}
	simple.like 107, getter.peek(), {line: 'line1'}
	simple.falsy 108, getter.eof()
	simple.like 109, getter.get(), {line: 'line1'}
	simple.like 110, getter.get(), {line: 'line2'}
	simple.equal 111, getter.lineNum, 2

	simple.falsy 113, getter.eof()
	simple.succeeds 114, () -> getter.unfetch({
		line: 'line5'
		str: 'line5'
		prefix: ''
		})
	simple.succeeds 115, () -> getter.unfetch({
		line: 'line6'
		str: 'line6'
		prefix: ''
		})
	simple.like 116, getter.get(), {line: 'line6'}
	simple.like 117, getter.get(), {line: 'line5'}
	simple.falsy 118, getter.eof()

	simple.like 120, getter.get(), {line: 'line3'}
	simple.truthy 121, getter.eof()
	simple.succeeds 122, () -> getter.unfetch({
		line: 'line13'
		str: 'line13'
		prefix: ''
		})
	simple.falsy 123, getter.eof()
	simple.like 124, getter.get(), {line: 'line13'}
	simple.truthy 125, getter.eof()
	simple.equal 126, getter.lineNum, 3
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

	simple.like 146, getter.peek(), {line: {a:1, b:2}}
	simple.like 147, getter.peek(), {line: {a:1, b:2}}
	simple.falsy 148, getter.eof()
	simple.like 149, getter.get(), {line: {a:1, b:2}}
	simple.like 150, getter.get(), {line: ['a','b']}

	simple.falsy 152, getter.eof()
	simple.succeeds 153, () -> getter.unfetch({line: []})
	simple.succeeds 154, () -> getter.unfetch({line: {}})
	simple.like 155, getter.get(), {line: {}}
	simple.like 156, getter.get(), {line: []}
	simple.falsy 157, getter.eof()

	simple.like 159, getter.get(), {line: 42}
	simple.like 160, getter.get(), {line: 'xyz'}
	simple.truthy 161, getter.eof()
	simple.succeeds 162, () -> getter.unfetch({line: 13})
	simple.falsy 163, getter.eof()
	simple.like 164, getter.get(), {line: 13}
	simple.truthy 165, getter.eof()
	simple.equal 166, getter.lineNum, 4
	)()

# ---------------------------------------------------------------------------

(() ->
	getter = new Getter(import.meta.url, """
			abc
			def
			""", {prefix: '---'})

	simple.equal 177, getter.getBlock(), """
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
			block = getter.getBlock()
			numLines = getter.lineNum   # set variable numLines
			return block

	# ..........................................................

	tester = new MyTester()

	tester.equal 203, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	simple.equal 214, numLines, 2
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

	simple.like 230, getter.peek(), {line: 'if (x == 2)'}
	simple.like 231, getter.get(),  {line: 'if (x == 2)'}

	simple.like 233, getter.peek(), {line: '\tdoThis'}
	simple.like 234, getter.get(),  {line: '\tdoThis'}

	simple.like 236, getter.peek(), {line: '\tdoThat'}
	simple.like 237, getter.get(),  {line: '\tdoThat'}

	simple.like 239, getter.peek(), {line: '\t\tthen this'}
	simple.like 240, getter.get(),  {line: '\t\tthen this'}

	simple.like 242, getter.peek(), {line: 'while (x > 2)'}
	simple.like 243, getter.get(),  {line: 'while (x > 2)'}

	simple.like 245, getter.peek(), {line: '\t--x'}
	simple.like 246, getter.get(),  {line: '\t--x'}

	)()

# ---------------------------------------------------------------------------

(() ->

	# --- Pre-declare all variables that are assigned to

	class VarGetter extends Getter

		init: () ->

			@lVars = []
			return

		# .......................................................

		map: (hLine) ->

			if lMatches = hLine.line.match(///^
					([A-Za-z_][A-Za-z0-9_]*)    # an identifier
					\s*
					=
					///)
				[_, varName] = lMatches
				@lVars.push varName

			return hLine.line

		# .......................................................

		finalizeBlock: (block) ->

			strVars = @lVars.join(',')
			return phReplace(block, {'vars': strVars})

		# .......................................................

	getter = new VarGetter(undef, """
			var #{phStr('vars')}
			x = 2
			y = 3
			""")
	result = getter.getBlock()
	simple.equal 292, result, """
			var x,y
			x = 2
			y = 3
			"""

	)()
