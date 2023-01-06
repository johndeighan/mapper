# FuncHereDoc.coffee

import {minify} from 'uglify-js'

import {
	undef, defined, notdefined, CWS,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {firstLine} from '@jdeighan/coffee-utils/block'
import {BaseHereDoc, addHereDocType} from '@jdeighan/mapper/heredoc'
import {cieloToJSExpr} from '@jdeighan/mapper/cielo'

# ---------------------------------------------------------------------------

export class FuncHereDoc extends BaseHereDoc

	mapToCielo: (block) ->

		dbgEnter "FuncHereDoc.mapToCielo", block
		lMatches = firstLine(block).match(///^
				\(
				\s*
				(?:                        # optional parameters
					[A-Za-z_][A-Za-z0-9_]*
					(?:
						\s*
						,
						\s*
						[A-Za-z_][A-Za-z0-9_]*
						)*
					)?
				\s*
				\)
				\s*
				=>
				\s*
				$///)
		if notdefined(lMatches)
			dbg "no match"
			dbgReturn 'FuncHereDoc.mapToCielo', undef
			return undef

		js = cieloToJSExpr(block).code
		dbg "js", js
		minijs = minify(js, {expression: true})
		dbg 'minijs', minijs

		result = "`" + minijs.code + "`"
		dbgReturn 'FuncHereDoc.mapToCielo', result
		return result

# ---------------------------------------------------------------------------

addHereDocType 'func', new FuncHereDoc()
