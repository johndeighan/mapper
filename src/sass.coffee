# sass.coffee

import sass from 'sass'

import {assert, undef} from '@jdeighan/coffee-utils'

import {isHashComment} from '@jdeighan/mapper/utils'
import {Mapper, doMap} from '@jdeighan/mapper'

convert = true

# ---------------------------------------------------------------------------

export convertSASS = (flag) ->

	convert = flag
	return

# ---------------------------------------------------------------------------

export class SassMapper extends Mapper
	# --- only removes comments

	handleComment: () ->

		return undef

# ---------------------------------------------------------------------------

export sassify = (block, source) ->

	newblock = doMap(SassMapper, source, block)
	if ! convert
		return newblock
	result = sass.renderSync({
		data: newblock,
		indentedSyntax: true,
		indentType: "tab",
		})
	return result.css.toString()
