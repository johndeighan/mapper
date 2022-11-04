# sass.coffee

import sass from 'sass'

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {dbg, dbgEnter, dbgReturn} from '@jdeighan/base-utils/debug'
import {undef} from '@jdeighan/coffee-utils'

import {isHashComment} from '@jdeighan/mapper/utils'
import {Mapper, map} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export sassify = (block, source) ->

	dbgEnter "sassify", block, source

	# --- NOTE: Mapper will remove comments and blank lines
	newblock = map(source, block, Mapper)
	dbg "newblock", newblock
	result = sass.renderSync({
		data: newblock,
		indentedSyntax: true,
		indentType: "tab",
		})
	result = result.css.toString()
	dbgReturn "sassify", result
	return result
