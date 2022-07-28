# sass.coffee

import sass from 'sass'

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {undef} from '@jdeighan/coffee-utils'

import {isHashComment} from '@jdeighan/mapper/utils'
import {Mapper, doMap} from '@jdeighan/mapper'
import {TreeWalker} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------

export class SassPreProcessor extends TreeWalker
	# --- only removes comments

	mapComment: () ->

		return undef

# ---------------------------------------------------------------------------

export sassify = (block, source) ->

	newblock = doMap(SassPreProcessor, source, block)
	result = sass.renderSync({
		data: newblock,
		indentedSyntax: true,
		indentType: "tab",
		})
	return result.css.toString()
