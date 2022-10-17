# RunTimeStack.coffee

import {LOG, LOGVALUE, debug, assert, croak} from '@jdeighan/exceptions'
import {
	undef, pass, defined, notdefined, OL, isString, isInteger, isHash,
	} from '@jdeighan/coffee-utils'
import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------

export class RunTimeStack

	constructor: () ->

		@lStack = []     # contains Node objects
		@len = 0

	# ..........................................................

	replaceTOS: (hNode) ->

		@checkNode hNode
		@lStack[@len-1] = hNode
		return

	# ..........................................................

	push: (hNode) ->

		@checkNode hNode
		@lStack.push hNode
		@len += 1
		return

	# ..........................................................

	pop: () ->

		assert (@len > 0), "pop() on empty stack"
		hNode = @lStack.pop()
		@checkNode hNode
		@len -= 1
		return hNode

	# ..........................................................

	isEmpty: () ->

		return (@len == 0)

	# ..........................................................

	nonEmpty: () ->

		return (@len > 0)

	# ..........................................................

	TOS: () ->

		if (@len > 0)
			hNode = @lStack[@len-1]
			@checkNode hNode
			return hNode
		else
			return undef

	# ..........................................................

	checkNode: (hNode) ->
		# --- Each node should have a key named hUser - a hash
		#     hUser should have a key named _parent - a hash

		assert (hNode instanceof Node), "not a Node"
		assert isHash(hNode.hUser), "missing hUser key"
		assert isHash(hNode.hUser._parent), "missing _parent key"
		return
