# utils.coffee

# ---------------------------------------------------------------------------

export isComment = (line) ->

	return line.match(/^\s*\#($|\s)/)

