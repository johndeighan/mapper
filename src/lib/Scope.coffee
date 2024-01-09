# Scope.coffee

import {undef, deepCopy} from '@jdeighan/base-utils'
import {LOG} from '@jdeighan/base-utils/log'

# ---------------------------------------------------------------------------

export class Scope

	constructor: (@name, lSymbols=undef) ->

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
