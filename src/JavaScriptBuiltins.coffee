# JavaScriptBuiltins.coffee

# ---------------------------------------------------------------------------

hJSBuiltins = {
	parseInt: true
	process: true
	JSON: true
	import: true
	}

# ---------------------------------------------------------------------------

export isBuiltin = (sym) ->

	return if hJSBuiltins[sym]? then true else false
