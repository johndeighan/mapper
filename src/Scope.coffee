# Scope.coffee

import {LOG} from '@jdeighan/base-utils'
import {undef, deepCopy} from '@jdeighan/coffee-utils'

# ---------------------------------------------------------------------------

export class Scope

	constructor: (@name=undef, lSymbols=undef) ->

		if (lSymbols == undef)
			@lSymbols = []
		else
			@lSymbols = deepCopy lSymbols

	# ..........................................................

	add: (symbol) ->

		if ! @lSymbols.includes(symbol)
			@lSymbols.push symbol
		return

	# ..........................................................

	has: (symbol) ->

		return @lSymbols.includes(symbol)

	# ..........................................................

	dump: () ->

		for symbol in @lSymbols
			LOG "      #{symbol}"
		return
