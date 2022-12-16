# Node.coffee

import {LOG, LOGVALUE, assert, croak} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {
	undef, pass, defined, notdefined, OL, isString, isInteger,
	} from '@jdeighan/coffee-utils'
import {
	indented, indentLevel, splitPrefix,
	} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------

export class Node

	constructor: (hNodeDesc) ->

		@checkNode hNodeDesc
		Object.assign(this, hNodeDesc)
		@checkNode this

		# --- level may later be adjusted, but srcLevel should be const
		@srcLevel = @level

	# ..........................................................

	checkNode: (h) ->

		assert isString(h.str), "str #{OL(h.str)} not a string"
		assert isInteger(h.level, {min: 0}),
			"level #{OL(h.level)} not an integer"
		assert isString(h.source), "source #{OL(@source)} not a string"
		assert isInteger(h.lineNum, {min: 1}),
			"lineNum #{OL(h.lineNum)} not an integer"
		return

	# ..........................................................
	# --- used when '#include <file>' has indentation

	incLevel: (n=1) ->

		@level += n
		return

	# ..........................................................

	getLine: (oneIndent="\t") ->

		return indented(@str, @level, oneIndent)
