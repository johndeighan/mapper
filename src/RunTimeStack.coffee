# RunTimeStack.coffee

import {undef, assert, croak} from '@jdeighan/coffee-utils'

# ---------------------------------------------------------------------------

export class RunTimeStack

	constructor: () ->

		@lStack = []

	# ..........................................................

	TOS: () ->

		if @lStack.length == 0
			return undef
		else
			return @lStack[@lStack.length - 1]

	# ..........................................................

	push: (uobj, level, lineNum, hUser) ->

		@lStack.push {
			uobj
			level
			lineNum
			hUser
			parent: @lStack.TOS()
			}

	# ..........................................................

	pop: () ->

		h = @lStack.pop()
		return [h.uobj, h.level, h.lineNum, h.hUser, h.parent]
