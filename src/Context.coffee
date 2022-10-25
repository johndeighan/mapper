# Context.coffee

import {assert, LOG, debug} from '@jdeighan/exceptions'
import {undef, deepCopy, words, OL} from '@jdeighan/coffee-utils'
import {Scope} from '@jdeighan/mapper/scope'

lBuiltins = words "parseInt process JSON import console",
                  "Function String Number Boolean Object Set",
                  "Math Date"

# ---------------------------------------------------------------------------

export class Context

	constructor: () ->

		@globalScope = new Scope('global', lBuiltins)
		@lScopes = [ @globalScope ]
		@currentScope = @globalScope

	# ..........................................................

	atGlobalLevel: () ->

		result = (@currentScope == @globalScope)
		if result
			assert (@lScopes.length == 1), "more than one scope"
			return true
		else
			return false

	# ..........................................................

	add: (symbol) ->

		debug "enter Context.add(#{OL(symbol)})"
		@currentScope.add(symbol)
		debug "return from Context.add()"
		return

	# ..........................................................

	addGlobal: (symbol) ->

		debug "enter Context.addGlobal(#{OL(symbol)})"
		@globalScope.add(symbol)
		debug "return from Context.addGlobal()"
		return

	# ..........................................................

	has: (symbol) ->

		for scope in @lScopes
			if scope.has(symbol)
				return true
		return false

	# ..........................................................

	beginScope: (name=undef, lSymbols=undef) ->

		debug "enter beginScope()"
		newScope = new Scope(name, lSymbols)
		@lScopes.unshift newScope
		@currentScope = newScope
		debug "return from beginScope()"
		return

	# ..........................................................

	endScope: () ->

		debug "enter endScope()"
		@lScopes.shift()    # remove ended scope
		@currentScope = @lScopes[0]
		debug "return from endScope()"
		return

	# ..........................................................

	dump: () ->

		for scope in @lScopes
			LOG "   SCOPE:"
			scope.dump()
		return
