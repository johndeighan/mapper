# sass.coffee

import sass from 'sass'

import {undef, isHashComment} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'

import {Mapper, map} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export sassify = (block) ->

	dbgEnter "sassify", block

	# --- NOTE: Mapper will remove comments and blank lines
	newblock = map(block, Mapper)
	dbg "newblock", newblock
	result = sass.renderSync({
		data: newblock,
		indentedSyntax: true,
		indentType: "tab",
		})
	result = result.css.toString()
	dbgReturn "sassify", result
	return result
