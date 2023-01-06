# Node.coffee

import {
	undef, pass, defined, notdefined, OL, isEmpty, nonEmpty,
	isString, isBoolean, isInteger, getOptions,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {
	indented, indentLevel, splitPrefix,
	} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------

export class Node

	constructor: (hNodeDesc) ->
		# --- Keys 'str' and 'level' are required
		#     Keys 'source' and 'lineNum' are optional

		Object.assign(this, hNodeDesc)

		assert isString(@str), "str #{OL(@str)} not a string"
		assert isInteger(@level, {min: 0}),
			"level #{OL(@level)} not an integer"
		if defined(@source)
			assert isString(@source), "source not a string"

		# --- level may later be adjusted, but srcLevel should be const
		@srcLevel = @level

	# ..........................................................

	desc: () ->

		str = "[#{@level}] #{OL(@str)}"
		if defined(@uobj) && (@uobj != @str)
			str += " #{OL(@uobj)}"
		return str

	# ..........................................................

	isEmptyLine: () ->

		str = @uobj || @str
		if !isString(str) || nonEmpty(str)
			return false
		assert (str == ''), "empty node is not empty string"
		assert (@level == 0), "empty node not at level 0"
		return true

	# ..........................................................
	# --- used when '#include <file>' has indentation

	incLevel: (n=1) ->

		@level += n
		return

	# ..........................................................
	# --- getLine() should only be called when text is desired,
	#        e.g. in getBlock()

	getLine: (hOptions={}) ->

		dbgEnter 'Node.getLine', hOptions

		# --- empty lines never get undented
		if @isEmptyLine()
			dbgReturn 'Node.getLine', ''
			return ''

		{oneIndent, undent} = getOptions(hOptions, {
			oneIndent: "\t"
			undent: 0
			})
		if (oneIndent != "\t")
			dbg "oneIndent = #{OL(oneIndent)}"

		if (undent == true)
			croak "undent set to true"
		else if (undent == false)
			undent = 0

		assert isInteger(undent), "undent not an integer"
		if (undent > 0)
			dbg "undent #{OL(undent)} levels"

		# --- If Node has key 'uobj', use that to build the line
		#     else use key 'str'
		str = @uobj || @str
		assert isString(str), "not a string: #{OL(str)}"
		assert (@level >= undent), "undent = #{undent}, level = #{@level}"
		result = indented(str, @level - undent, oneIndent)
		dbgReturn 'Node.getLine', result
		return result
