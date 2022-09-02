# Node.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, defined, notdefined, OL, isString, isInteger,
	} from '@jdeighan/coffee-utils'
import {
	indented, indentLevel, splitPrefix,
	} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------

export class Node

	constructor: (@str, @level, @source, @lineNum, hData) ->

		assert isString(@str), "str is #{OL(@str)}"
		assert isInteger(@level, {min: 0}), "level is #{OL(@level)}"
		assert isString(@source), "source is #{OL(@source)}"
		assert isInteger(@lineNum, {min: 0}), "lineNum is #{OL(@lineNum)}"

		# --- level may later be adjusted, but srcLevel should be const
		@srcLevel = @level
		Object.assign(this, hData)

	# ..........................................................
	# --- used when '#include <file>' has indentation

	incLevel: (n) ->

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
