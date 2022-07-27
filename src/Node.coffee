# Node.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, defined, notdefined, OL, isString, isInteger,
	} from '@jdeighan/coffee-utils'
import {indentLevel, splitPrefix} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------

export class Node

	constructor: (@str, @level, @source, @lineNum) ->

		assert isString(@str), "str is #{OL(@str)}"
		assert isInteger(@level, {min: 0}), "level is #{OL(@level)}"
		assert isString(@source), "source is #{OL(@source)}"
		assert isInteger(@lineNum, {min: 0}), "lineNum is #{OL(@lineNum)}"

		# --- level may later be adjusted, but srcLevel should be const
		@srcLevel = @level

	# ..........................................................
	# --- used when '#include <file>' has indentation

	incLevel: (n) ->

		@level += n
		return

	# ..........................................................

	setUserObj: (uobj) ->

		assert defined(uobj), "uobj is #{OL(uobj)}"
		@uobj = uobj
		return

	# ..........................................................

	isMapped: () ->

		return defined(@uobj)

	# ..........................................................

	getIndent: (oneIndent) ->

		if defined(oneIndent)
			return oneIndent.repeat(@level)
		else
			assert (@level==0), "undef oneIndent, level = #{OL(@level)}"
			return ''

	# ..........................................................

	getLine: (oneIndent) ->

		return @getIndent(oneIndent) + @str

	# ..........................................................

	getMappedLine: (oneIndent) ->

		assert isString(@uobj), "uobj is #{OL(@uobj)}"
		return @getIndent(oneIndent) + @uobj
