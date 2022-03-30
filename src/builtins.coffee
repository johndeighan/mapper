# builtins.coffee

# ---------------------------------------------------------------------------

hJSBuiltins = {
	parseInt: true
	process: true
	JSON: true
	import: true
	console: true
	}

# ---------------------------------------------------------------------------

export isBuiltin = (sym) ->

	return if hJSBuiltins[sym]? then true else false
