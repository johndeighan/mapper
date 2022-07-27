# sass.coffee

import sass from 'sass'

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {undef} from '@jdeighan/coffee-utils'

import {isHashComment} from '@jdeighan/mapper/utils'
import {Mapper, doMap} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export class SassMapper extends Mapper
	# --- only removes comments

	mapComment: () ->

		return undef

# ---------------------------------------------------------------------------

export sassify = (block, source) ->

	newblock = doMap(SassMapper, source, block)
	result = sass.renderSync({
		data: newblock,
		indentedSyntax: true,
		indentType: "tab",
		})
	return result.css.toString()
