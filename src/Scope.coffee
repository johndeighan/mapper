# Scope.coffee

# ---------------------------------------------------------------------------

export class Scope

	constructor: () ->

		@lSymbols = []

	# ..........................................................

	addSymbol: (symbol) ->

		if ! @lSymbols.includes(symbol)
			@lSymbols.push symbol
		return

	# ..........................................................

	includes: (symbol) ->

		return @lSymbols.includes(symbol)
