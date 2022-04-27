# sass.coffee

import sass from 'sass'

import {assert, undef} from '@jdeighan/coffee-utils'

import {isComment} from '@jdeighan/mapper/utils'
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

export sassify = (block, source) ->

	oInput = new SassMapper(block, source)
	newblock = oInput.getBlock()
	if ! convert
		return newblock
	result = sass.renderSync({
		data: newblock,
		indentedSyntax: true,
		indentType: "tab",
		})
	return result.css.toString()
