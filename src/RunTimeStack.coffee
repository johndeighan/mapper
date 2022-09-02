# RunTimeStack.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, defined, notdefined, OL, isString, isInteger,
	} from '@jdeighan/coffee-utils'
import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------

export class RunTimeStack

	constructor: () ->

		@lStack = []     # contains Node objects
		@len = 0

	# ..........................................................

	replaceTOS: (node) ->

		assert (node instanceof Node), "not a Node"
		@lStack[@len-1] = node
		return

	# ..........................................................

	push: (node) ->

		assert (node instanceof Node), "not a Node"
		@lStack.push node
		@len += 1
		return

	# ..........................................................

	pop: () ->

		assert (@len > 0), "pop() on empty stack"
		item = @lStack.pop()
		@len -= 1
		return item

	# ..........................................................

	isEmpty: () ->

		return (@len == 0)

	# ..........................................................

	nonEmpty: () ->

		return (@len > 0)

	# ..........................................................

	TOS: () ->

		if (@len > 0)
			return @lStack[@len-1]
		else
			return undef
