# debar.coffee

import {
	undef, pass, assert, isEmpty, nonEmpty, replaceVars,
	} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {Mapper} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export debar = (block, hVars={}) ->
	# --- returns an array of blocks

	mapper = new DeBarMapper(block, hVars)
	return mapper.getBlock()

# ---------------------------------------------------------------------------

class DeBarMapper extends Mapper

	constructor: (content, @hMyVars) ->

		assert nonEmpty(content), "DeBarMapper(): empty content"
		super content, 'debar'

	# ..........................................................

	mapLine: (line, level) ->

		lMatches = line.match(///^
				\s*
				(?: \# | \/\/ )   # allow both CoffeeScript and JavaScript style
				\s+
				\|\|
				(\d+)?
				\|\|
				\s*
				(.*)
				$///)
		if !lMatches then return line
		[_, level, tail] = lMatches
		replaced = replaceVars(tail, @hMyVars)
		if isEmpty(replaced)
			return undef
		else if level
			return indented(replaced, parseInt(level))
		else
			return replaced
