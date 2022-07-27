# Getter.test.coffee

import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, rtrim, replaceVars,
	} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {
	arrayToBlock, joinBlocks,
	} from '@jdeighan/coffee-utils/block'
import {phStr, phReplace} from '@jdeighan/coffee-utils/placeholders'

import {Node} from '@jdeighan/mapper/node'
import {Getter} from '@jdeighan/mapper/getter'

simple = new UnitTester()

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter(undef, ['line1', 'line2', 'line3'])

	simple.like 26, getter.peek(), {str: 'line1'}
	simple.like 27, getter.peek(), {str: 'line1'}
	simple.falsy 28, getter.eof()
	simple.like 29, node1 = getter.get(), {str: 'line1'}
	simple.like 30, node2 = getter.get(), {str: 'line2'}
	simple.equal 31, getter.lineNum, 2

	simple.falsy 33, getter.eof()
	simple.succeeds 34, () -> getter.unfetch(node2)
	simple.succeeds 35, () -> getter.unfetch(node1)
	simple.like 36, getter.get(), {str: 'line1'}
	simple.like 37, getter.get(), {str: 'line2'}
	simple.falsy 38, getter.eof()

	simple.like 40, node3 = getter.get(), {str: 'line3'}
	simple.equal 41, getter.lineNum, 3
	simple.truthy 42, getter.eof()
	simple.succeeds 43, () -> getter.unfetch(node3)
	simple.falsy 44, getter.eof()
	simple.like 45, getter.get(), {str: 'line3'}
	simple.truthy 46, getter.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	getter = new Getter(undef, ['abc', 'def  ', 'ghi\t\t'])

	simple.like 56, getter.peek(), {str: 'abc'}
	simple.like 57, getter.peek(), {str: 'abc'}
	simple.falsy 58, getter.eof()
	simple.like 59, getter.get(), {str: 'abc'}
	simple.like 60, getter.get(), {str: 'def'}
	simple.like 61, getter.get(), {str: 'ghi'}
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

	simple.like 78, getter.fetch(), {str: 'abc'}

	# 'jkl' will be discarded
	simple.like 81, getter.fetchUntil('jkl'), [
		{str: 'def'}
		{str: 'ghi'}
		]

	simple.like 86, getter.fetch(), {str: 'mno'}
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

	simple.like 106, getter.peek(), {str: 'line1'}
	simple.like 107, getter.peek(), {str: 'line1'}
	simple.falsy 108, getter.eof()
	simple.like 109, node1 = getter.get(), {str: 'line1'}
	simple.like 110, node2 = getter.get(), {str: 'line2'}
	simple.equal 111, getter.lineNum, 2

	simple.falsy 113, getter.eof()
	simple.succeeds 114, () -> getter.unfetch(node2)
	simple.succeeds 115, () -> getter.unfetch(node1)
	simple.like 116, getter.get(), {str: 'line1'}
	simple.like 117, getter.get(), {str: 'line2'}
	simple.falsy 118, getter.eof()

	simple.like 120, node3 = getter.get(), {str: 'line3'}
	simple.truthy 121, getter.eof()
	simple.succeeds 122, () -> getter.unfetch(node3)
	simple.falsy 123, getter.eof()
	simple.like 124, getter.get(), {str: 'line3'}
	simple.truthy 125, getter.eof()
	simple.equal 126, getter.lineNum, 3
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

	simple.like 230, getter.peek(), {str: 'if (x == 2)'}
	simple.like 231, getter.get(),  {str: 'if (x == 2)'}

	simple.like 233, getter.peek(), {str: '\tdoThis'}
	simple.like 234, getter.get(),  {str: '\tdoThis'}

	simple.like 236, getter.peek(), {str: '\tdoThat'}
	simple.like 237, getter.get(),  {str: '\tdoThat'}

	simple.like 239, getter.peek(), {str: '\t\tthen this'}
	simple.like 240, getter.get(),  {str: '\t\tthen this'}

	simple.like 242, getter.peek(), {str: 'while (x > 2)'}
	simple.like 243, getter.get(),  {str: 'while (x > 2)'}

	simple.like 245, getter.peek(), {str: '\t--x'}
	simple.like 246, getter.get(),  {str: '\t--x'}

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
