# Context.coffee

import {Scope} from '@jdeighan/mapper/scope'

# ---------------------------------------------------------------------------

export class Context

	constructor: () ->

		@rootScope = new Scope()
		@lScopes = [@rootScope]

	# ..........................................................

	exists: (symbol) ->

		for scope in @lScopes
			if scope.includes(symbol)
				return true
		return false
