# utils.coffee

# ---------------------------------------------------------------------------

export isHashComment = (line) ->

	return line.match(/^\s*\#($|\s)/)

