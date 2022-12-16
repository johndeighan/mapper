# Getter.test.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {setDebugging, dbgEnter, dbgReturn, dbg} from '@jdeighan/base-utils/debug'
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

	getter = new Getter({content: ['line1', 'line2', 'line3']})

	utest.like 22, node1 = getter.get(), {str: 'line1'}
	utest.like 23, node2 = getter.get(), {str: 'line2'}
	utest.equal 24, getter.lineNum, 2

	utest.like 26, node3 = getter.get(), {str: 'line3'}
	utest.equal 27, getter.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	getter = new Getter({content: ['abc', 'def  ', 'ghi\t\t']})

	utest.like 37, getter.get(), {str: 'abc'}
	utest.like 38, getter.get(), {str: 'def'}
	utest.like 39, getter.get(), {str: 'ghi'}
	utest.equal 40, getter.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Test get(), getUntil()

(() ->

	getter = new Getter({content: """
			abc
			def
			ghi
			jkl
			mno
			"""})

	utest.like 56, getter.get(), {str: 'abc'}

	# 'jkl' will be discarded
	func = (hNode) -> return (hNode.str == 'jkl')

	lItems = []
	for item from getter.allUntil(func)
		lItems.push item
	utest.like 64, lItems, [
		{str: 'def'}
		{str: 'ghi'}
		]

	utest.like 69, getter.get(), {str: 'mno'}
	utest.equal 70, getter.lineNum, 5
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
	getter = new Getter({content: generator()})

	utest.like 89, node1 = getter.get(), {str: 'line1'}
	utest.like 90, node2 = getter.get(), {str: 'line2'}
	utest.equal 91, getter.lineNum, 2

	utest.like 93, node3 = getter.get(), {str: 'line3'}
	utest.equal 94, getter.lineNum, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter({content: """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			"""})

	utest.like 110, getter.get(),  {str: 'if (x == 2)', level: 0}
	utest.like 111, getter.get(),  {str: 'doThis', level: 1}
	utest.like 112, getter.get(),  {str: 'doThat', level: 1}
	utest.like 113, getter.get(),  {str: 'then this', level: 2}
	utest.like 114, getter.get(),  {str: 'while (x > 2)', level: 0}
	utest.like 115, getter.get(),  {str: '--x', level: 1}

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

			dbgEnter 'mapNonSpecial', hNode
			if lMatches = hNode.str.match(///^
					([A-Za-z_][A-Za-z0-9_]*)    # an identifier
					\s*
					=
					///)
				[_, varName] = lMatches
				dbg "found var #{varName}"
				@lVars.push varName

			dbgReturn 'mapNonSpecial', hNode.str
			return hNode.str

		# .......................................................

		finalizeBlock: (block) ->

			dbgEnter 'finalizeBlock'
			strVars = @lVars.join(',')
			result = block.replace('__vars__', strVars)
			dbgReturn 'finalizeBlock', result
			return result

		# .......................................................

	getter = new VarGetter({content: """
			var __vars__
			x = 2
			y = 3
			"""})
	result = getter.getBlock()
	utest.like 160, result, """
			var x,y
			x = 2
			y = 3
			"""

	)()
