# RunTimeStack.coffee

import {
	undef, defined, notdefined, OL, isHash, toBlock,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'

import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------

export class RunTimeStack

	constructor: () ->

		@lStack = []     # contains Node objects

	# ..........................................................

	size: () ->

		return @lStack.length

	# ..........................................................

	replaceTOS: (hNode) ->

		@checkNode hNode
		@lStack[@lStack.length - 1] = hNode
		return

	# ..........................................................

	push: (hNode) ->

		@checkNode hNode
		@lStack.push hNode
		return

	# ..........................................................

	pop: () ->

		assert (@lStack.length > 0), "pop() on empty stack"
		hNode = @lStack.pop()
		@checkNode hNode
		return hNode

	# ..........................................................

	isEmpty: () ->

		return (@lStack.length == 0)

	# ..........................................................

	nonEmpty: () ->

		return (@lStack.length > 0)

	# ..........................................................

	TOS: () ->

		if (@lStack.length == 0)
			return undef
		hNode = @lStack[@lStack.length - 1]
		@checkNode hNode
		return hNode

	# ..........................................................

	desc: () ->

		lLines = ["--- STACK (#{@lStack.length} items) ---"]
		for hNode in @lStack
			item = JSON.stringify(hNode, undef, 3)
			lLines.push item
		lLines.push "-----------------------"
		return toBlock(lLines)

	# ..........................................................

	checkNode: (hNode) ->
		# --- Each node should have a key named hUser - a hash
		#     hUser should have a key named _parent - a hash

		assert (hNode instanceof Node), "not a Node"
		assert isHash(hNode.hEnv), "missing hEnv key in #{OL(hNode)}"
		return
