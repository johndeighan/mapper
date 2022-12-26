# Getter.test.coffee

import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, dumpLog} from '@jdeighan/base-utils/log'
import {
	setDebugging, dbgEnter, dbgReturn, dbg,
	} from '@jdeighan/base-utils/debug'
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
# --- Getter should:
#     ✓ implement get()
#     ✓ define and replace constants in any non-special lines
#     - allow defining special types
#          - by overriding getItemType(hNode) and mapSpecial(type, hNode)
#     - allow override of mapNonSpecial(hNode)
#     - implement generator all(stopperFunc)
# ---------------------------------------------------------------------------
# --- Test get()

(() ->

	getter = new Getter("""
		abc
		def
		ghi
		jkl
		mno
		""")

	utest.like 40, getter.get(), {str: 'abc', level: 0}

	stopperFunc = (hNode) -> return (hNode.str == 'jkl')

	lItems = []
	for hNode from getter.all(stopperFunc)
		lItems.push hNode

	utest.like 48, lItems, [
		{str: 'def'}
		{str: 'ghi'}
		]

	utest.like 53,  getter.get(), {str: 'jkl', level: 0}
	utest.like 54,  getter.get(), {str: 'mno', level: 0}
	utest.equal 55, getter.lineNum, 5
	utest.equal 56, getter.get(), undef
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

	utest.like 75, node1 = getter.get(), {str: 'line1', level: 0}
	utest.like 76, node2 = getter.get(), {str: 'line2', level: 0}
	utest.equal 77, getter.lineNum, 2

	utest.like 79, node3 = getter.get(), {str: 'line3', level: 0}
	utest.equal 80, getter.lineNum, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter("""
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	utest.like 96, getter.get(),  {str: 'if (x == 2)', level: 0}
	utest.like 97, getter.get(),  {str: 'doThis', level: 1}
	utest.like 98, getter.get(),  {str: 'doThat', level: 1}
	utest.like 99, getter.get(),  {str: 'then this', level: 2}
	utest.like 100, getter.get(),  {str: 'while (x > 2)', level: 0}
	utest.like 101, getter.get(),  {str: '--x', level: 1}

	)()

# ---------------------------------------------------------------------------

(() ->
	getter = new Getter("""
		abc
		meaning is __meaning__
		my name is __name__
		""")
	getter.setConst 'meaning', '42'
	getter.setConst 'name', 'John Deighan'
	utest.equal 115, getter.getBlock(), """
		abc
		meaning is 42
		my name is John Deighan
		"""
	)()

# ---------------------------------------------------------------------------

(() ->
	# --- Pre-declare all variables that are assigned to

	class VarGetter extends Getter

		init: () ->

			@lVars = []
			return

		# .......................................................

		mapNode: (hNode) ->

			dbgEnter 'mapNode', hNode
			if lMatches = hNode.str.match(///^
					([A-Za-z_][A-Za-z0-9_]*)    # an identifier
					\s*
					=
					///)
				[_, varName] = lMatches
				dbg "found var #{varName}"
				@lVars.push varName

			dbgReturn 'mapNode', hNode.str
			return hNode.str

		# .......................................................

		finalizeBlock: (block) ->

			dbgEnter 'finalizeBlock'
			strVars = @lVars.join(',')
			result = block.replace('__vars__', strVars)
			dbgReturn 'finalizeBlock', result
			return result

		# .......................................................

	getter = new VarGetter("""
			var __vars__
			x = 2
			y = 3
			""")
	result = getter.getBlock()
	utest.like 169, result, """
			var x,y
			x = 2
			y = 3
			"""

	)()
