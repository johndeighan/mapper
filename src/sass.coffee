# sass.coffee

import sass from 'sass'

import {LOG, assert, croak, debug} from '@jdeighan/exceptions'
import {undef} from '@jdeighan/coffee-utils'

import {isHashComment} from '@jdeighan/mapper/utils'
import {Mapper, map} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export sassify = (block, source) ->

	debug "enter sassify()", block, source

	# --- NOTE: Mapper will remove comments and blank lines
	newblock = map(source, block, Mapper)
	debug "newblock", newblock
	result = sass.renderSync({
		data: newblock,
		indentedSyntax: true,
		indentType: "tab",
		})
	result = result.css.toString()
	debug "return from sassify()", result
	return result
