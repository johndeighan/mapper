# Getter.test.coffee

import {
	undef, defined, notdefined, rtrim,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {
	setDebugging, dbgEnter, dbgReturn, dbg,
	} from '@jdeighan/base-utils/debug'
import {UnitTester, equal, like} from '@jdeighan/base-utils/utest'

import {Node} from '@jdeighan/mapper/node'
import {Getter} from '@jdeighan/mapper/getter'

# ---------------------------------------------------------------------------
# --- Getter should:
#     ✓ implement get()
#     ✓ define and replace constants
#     - allow defining special types
#          - by overriding getItemType(hNode) and mapNode(hNode)
#     - implement generator allNodes()
#          - by overriding procNode()
# ---------------------------------------------------------------------------
# --- Test get()

(() ->

	getter = new Getter("""
		abc
		def
		ghi
		""")

	like getter.get(), {
		str: 'abc'
		level: 0
		}

	lItems = []
	for hNode from getter.allNodes()
		lItems.push hNode

	like lItems, [
		{str: 'def'}
		{str: 'ghi'}
		]

	equal getter.get(), undef
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

	like node1 = getter.get(), {
		str: 'line1'
		level: 0
		source: "<unknown>/1"
		}
	like node2 = getter.get(), {
		str: 'line2'
		level: 0
		source: "<unknown>/2"
		}

	like node3 = getter.get(), {
		str: 'line3'
		level: 0
		source: "<unknown>/3"
		}
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

	like getter.get(),  {str: 'if (x == 2)', level: 0}
	like getter.get(),  {str: 'doThis', level: 1}
	like getter.get(),  {str: 'doThat', level: 1}
	like getter.get(),  {str: 'then this', level: 2}
	like getter.get(),  {str: 'while (x > 2)', level: 0}
	like getter.get(),  {str: '--x', level: 1}

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
	equal getter.getBlock(), """
		abc
		meaning is 42
		my name is John Deighan
		"""
	)()

# ---------------------------------------------------------------------------

(() ->
	# --- Pre-declare all variables that are assigned to

	class VarGetter extends Getter

		constructor: (hInput, options) ->

			super hInput, options
			@lVars = []
			return

		# .......................................................

		mapNode: (hNode) ->

			dbgEnter 'VarGetter.mapNode', hNode
			if lMatches = hNode.str.match(///^
					([A-Za-z_][A-Za-z0-9_]*)    # an identifier
					\s*
					=
					///)
				[_, varName] = lMatches
				dbg "found var #{varName}"
				@lVars.push varName

			dbgReturn 'VarGetter.mapNode', hNode.str
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
	equal result, """
			var x,y
			x = 2
			y = 3
			"""

	)()

# ---------------------------------------------------------------------------

(() ->
	# --- change '#<cmd> <args>' to 'COMMAND <cmd> <args>'
	#     skip comments

	class MyGetter extends Getter

		getItemType: (hNode) ->
			# --- We go ahead and set uobj in here,
			#     then just return it in mapNode()
			#     upper case anything else

			{str} = hNode
			assert notdefined(str.match(/^\s/)), "str has leading ws"
			lMatches = str.match(///^
				\#
				(\s*)
				(\S*)
				\s*
				(.*)
				$///)
			if notdefined(lMatches)
				hNode.uobj = hNode.str.toUpperCase()
				return undef     # not a special type
			[_, ws, cmd, args] = lMatches
			if (ws.length > 0) || (cmd.length == 0)
				hNode.uobj = undef   # forces comments to be skipped
				return 'comment'
			else
				hNode.uobj = "COMMAND #{cmd} #{args}"
				return 'command'

		mapNode: (hNode) ->

			return hNode.uobj

	# .......................................................

	getter = new MyGetter("""
			abc
			# this AND the following line are comments
			#
			#docmd temp.txt
			x = 2
			y = 3
			""")
	result = getter.getBlock()
	equal result, """
			ABC
			COMMAND docmd temp.txt
			X = 2
			Y = 3
			"""

	)()
