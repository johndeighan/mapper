# TraceWalker.coffee

import {assert, undef, defined, OL} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'

import {TreeWalker} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------

export class TraceWalker extends TreeWalker

	# ..........................................................
	#     builds a trace of the tree
	#        which is returned by endWalk()

	beginWalk: () ->

		@lTrace = ["BEGIN WALK"]   # an array of strings
		return

	# ..........................................................

	visit: (hLine, hUser, lStack) ->

		{uobj, level, type} = hLine
		if defined(type)
			@lTrace.push "VISIT     #{level} #{OL(uobj)} (#{type})"
		else
			@lTrace.push "VISIT     #{level} #{OL(uobj)}"
		return

	# ..........................................................

	endVisit: (hLine, hUser, lStack) ->

		{uobj, level, type} = hLine
		if defined(type)
			@lTrace.push "END VISIT #{level} #{OL(uobj)} (#{type})"
		else
			@lTrace.push "END VISIT #{level} #{OL(uobj)}"
		return

	# ..........................................................

	endWalk: () ->

		@lTrace.push "END WALK"
		block = arrayToBlock(@lTrace)
		@lTrace = undef
		return block

# ---------------------------------------------------------------------------
