# Getter.test.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {UnitTester, utest} from '@jdeighan/unit-tester'
import {
	undef, rtrim, replaceVars,
	} from '@jdeighan/coffee-utils'
import {
	arrayToBlock, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Node} from '@jdeighan/mapper/node'
import {Getter} from '@jdeighan/mapper/getter'

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter(undef, ['line1', 'line2', 'line3'])

	utest.like 24, getter.peek(), {str: 'line1'}
	utest.like 25, getter.peek(), {str: 'line1'}
	utest.falsy 26, getter.eof()
	utest.like 27, node1 = getter.get(), {str: 'line1'}
	utest.like 28, node2 = getter.get(), {str: 'line2'}
	utest.equal 29, getter.lineNum, 2

	utest.falsy 31, getter.eof()
	utest.succeeds 32, () -> getter.unfetch(node2)
	utest.succeeds 33, () -> getter.unfetch(node1)
	utest.like 34, getter.get(), {str: 'line1'}
	utest.like 35, getter.get(), {str: 'line2'}
	utest.falsy 36, getter.eof()

	utest.like 38, node3 = getter.get(), {str: 'line3'}
	utest.equal 39, getter.lineNum, 3
	utest.truthy 40, getter.eof()
	utest.succeeds 41, () -> getter.unfetch(node3)
	utest.falsy 42, getter.eof()
	utest.like 43, getter.get(), {str: 'line3'}
	utest.truthy 44, getter.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	getter = new Getter(undef, ['abc', 'def  ', 'ghi\t\t'])

	utest.like 54, getter.peek(), {str: 'abc'}
	utest.like 55, getter.peek(), {str: 'abc'}
	utest.falsy 56, getter.eof()
	utest.like 57, getter.get(), {str: 'abc'}
	utest.like 58, getter.get(), {str: 'def'}
	utest.like 59, getter.get(), {str: 'ghi'}
	utest.equal 60, getter.lineNum, 3
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

	utest.like 76, getter.fetch(), {str: 'abc'}

	# 'jkl' will be discarded
	func = (hNode) -> return (hNode.str == 'jkl')
	utest.like 80, getter.fetchUntil(func, 'discardEndLine'), [
		{str: 'def'}
		{str: 'ghi'}
		]

	utest.like 85, getter.fetch(), {str: 'mno'}
	utest.equal 86, getter.lineNum, 5
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

	utest.like 105, getter.peek(), {str: 'line1'}
	utest.like 106, getter.peek(), {str: 'line1'}
	utest.falsy 107, getter.eof()
	utest.like 108, node1 = getter.get(), {str: 'line1'}
	utest.like 109, node2 = getter.get(), {str: 'line2'}
	utest.equal 110, getter.lineNum, 2

	utest.falsy 112, getter.eof()
	utest.succeeds 113, () -> getter.unfetch(node2)
	utest.succeeds 114, () -> getter.unfetch(node1)
	utest.like 115, getter.get(), {str: 'line1'}
	utest.like 116, getter.get(), {str: 'line2'}
	utest.falsy 117, getter.eof()

	utest.like 119, node3 = getter.get(), {str: 'line3'}
	utest.truthy 120, getter.eof()
	utest.succeeds 121, () -> getter.unfetch(node3)
	utest.falsy 122, getter.eof()
	utest.like 123, getter.get(), {str: 'line3'}
	utest.truthy 124, getter.eof()
	utest.equal 125, getter.lineNum, 3
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

	utest.like 141, getter.peek(), {str: 'if (x == 2)', level: 0}
	utest.like 142, getter.get(),  {str: 'if (x == 2)', level: 0}

	utest.like 144, getter.peek(), {str: 'doThis', level: 1}
	utest.like 145, getter.get(),  {str: 'doThis', level: 1}

	utest.like 147, getter.peek(), {str: 'doThat', level: 1}
	utest.like 148, getter.get(),  {str: 'doThat', level: 1}

	utest.like 150, getter.peek(), {str: 'then this', level: 2}
	utest.like 151, getter.get(),  {str: 'then this', level: 2}

	utest.like 153, getter.peek(), {str: 'while (x > 2)', level: 0}
	utest.like 154, getter.get(),  {str: 'while (x > 2)', level: 0}

	utest.like 156, getter.peek(), {str: '--x', level: 1}
	utest.like 157, getter.get(),  {str: '--x', level: 1}

	)()

# ---------------------------------------------------------------------------
# --- test getAll(), getUntil()
#        they use allMapped() and allMappedUntil()

(() ->
	# --- There are no special item types in a Getter,
	#     so comments, blank lines, commands are all treated as plain strings

	block = """
		#starbucks webpage

		# --- comment
		h1 title
			p paragraph
		"""

	getter = new Getter(import.meta.url, block)
	utest.like 178, getter.getAll(), [
		{str: '#starbucks webpage', level: 0, uobj: '#starbucks webpage'}
		{str: '',                   level: 0, uobj: ''}
		{str: '# --- comment',      level: 0, uobj: '# --- comment'}
		{str: 'h1 title',           level: 0, uobj: 'h1 title'}
		{str: 'p paragraph',        level: 1, uobj: '\tp paragraph'}
		]

	func = (hNode) -> return (hNode.str.match(/^#\s/))

	getter = new Getter(import.meta.url, block)
	utest.like 189, getter.getUntil(func, 'discardEndLine'), [
		{str: '#starbucks webpage', level: 0, uobj: '#starbucks webpage'}
		{str: '',                   level: 0, uobj: ''}
		]
	utest.like 193, getter.get(), {
		str: 'h1 title'
		level: 0
		uobj: 'h1 title'
		}

	getter = new Getter(import.meta.url, block)
	utest.like 200, getter.getUntil(func, 'keepEndLine'), [
		{str: '#starbucks webpage', level: 0, uobj: '#starbucks webpage'}
		{str: '',                   level: 0, uobj: ''}
		]
	utest.like 204, getter.get(), {
		str: '# --- comment'
		level: 0
		uobj: '# --- comment'
		}

	)()

# ---------------------------------------------------------------------------

(() ->
	# --- Pre-declare all variables that are assigned to

	class VarGetter extends Getter

		init: () ->

			@lVars = []
			return

		# .......................................................

		mapNonSpecial: (hNode) ->

			if lMatches = hNode.str.match(///^
					([A-Za-z_][A-Za-z0-9_]*)    # an identifier
					\s*
					=
					///)
				[_, varName] = lMatches
				@lVars.push varName

			return hNode.str

		# .......................................................

		finalizeBlock: (block) ->

			strVars = @lVars.join(',')
			return block.replace('__vars__', strVars)

		# .......................................................

	getter = new VarGetter(undef, """
			var __vars__
			x = 2
			y = 3
			""")
	result = getter.getBlock()
	utest.like 253, result, """
			var x,y
			x = 2
			y = 3
			"""

	)()
