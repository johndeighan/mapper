# Node.coffee

import {LOG, LOGVALUE, assert, croak} from '@jdeighan/base-utils'
import {dbg, dbgEnter, dbgReturn} from '@jdeighan/base-utils/debug'
import {
	undef, pass, defined, notdefined, OL, isString, isInteger,
	} from '@jdeighan/coffee-utils'
import {
	indented, indentLevel, splitPrefix,
	} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------

export class Node

	constructor: (@str, @level, @source, @lineNum, hData) ->

		assert isString(@str), "str #{OL(@str)} not a string"
		assert isInteger(@level, {min: 0}),
			"level #{OL(@level)} not an integer"
		assert isString(@source), "source #{OL(@source)} not a string"
		assert isInteger(@lineNum, {min: 1}),
			"lineNum #{OL(@lineNum)} not an integer"

		# --- level may later be adjusted, but srcLevel should be const
		@srcLevel = @level
		Object.assign(this, hData)

	# ..........................................................
	# --- used when '#include <file>' has indentation

	incLevel: (n=1) ->

		@level += n
		return

	# ..........................................................

	isMapped: () ->

		return defined(@uobj)

	# ..........................................................

	notMapped: () ->

		return notdefined(@uobj)

	# ..........................................................

	getLine: (oneIndent) ->

		return indented(@str, @level, oneIndent)
