# sass.coffee

import sass from 'sass'

import {assert, undef, isComment} from '@jdeighan/coffee-utils'

import {Mapper} from '@jdeighan/mapper'

convert = true

# ---------------------------------------------------------------------------

export convertSASS = (flag) ->

	convert = flag
	return

# ---------------------------------------------------------------------------

export class SassMapper extends Mapper
	# --- only removes comments

	mapLine: (line, level) ->

		if isComment(line)
			return undef
		else
			return line

# ---------------------------------------------------------------------------

export sassify = (block) ->

	oInput = new SassMapper(block)
	newblock = oInput.getBlock()
	if ! convert
		return newblock
	result = sass.renderSync({
		data: newblock,
		indentedSyntax: true,
		indentType: "tab",
		})
	return result.css.toString()
