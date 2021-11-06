# JavaScriptBuiltins.coffee

# ---------------------------------------------------------------------------

hJSBuiltins = {
	parseInt: true
	process: true
	JSON: true
	}

# ---------------------------------------------------------------------------

export isBuiltin = (sym) ->

	return if hJSBuiltins[sym]? then true else false
