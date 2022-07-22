# Mapper.coffee

import {
	assert, undef, pass, croak, OL, rtrim, defined, escapeStr, className,
	isString, isHash, isArray, isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {splitPrefix, splitLine} from '@jdeighan/coffee-utils/indent'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Getter} from '@jdeighan/mapper/getter'

# ---------------------------------------------------------------------------
#   class Mapper
#       handles:
#          #include
#          #define
#          const replacement

export class Mapper extends Getter

	constructor: (source=undef, collection=undef, hOptions={}) ->

		debug "enter Mapper()"
		super source, collection, hOptions

		# --- These never change
		@setConst 'FILE', @hSourceInfo.filename
		@setConst 'DIR', @hSourceInfo.dir

		# --- This needs to be kept updated
		@setConst 'LINE', @lineNum

		# --- These must be bound to a specific object
		#     when called
		@hSpecials = {}
		@lSpecials = []    # checked in this order

		@addSpecial('empty', @isEmptyLine, @handleEmptyLine)
		@addSpecial('comment', @isComment, @handleComment)
		@addSpecial('cmd', @isCmd, @handleCmd)
		debug "return from Mapper()"

	# ..........................................................

	addSpecial: (type, recognizer, handler) ->

		@lSpecials.push(type)
		@hSpecials[type] = {
			recognizer
			handler
			}
		return

	# ..........................................................
	# --- override to keep variable LINE updated

	incLineNum: (inc=1) ->

		debug "enter incLineNum(#{inc})"
		super inc
		@setConst 'LINE', @lineNum
		debug "return from incLineNum()"
		return

	# ..........................................................
	# --- override
	#     LATER: maintain an ordered hash of types along with
	#            methods to check for those types

	getItemType: (hLine) ->

		debug "enter Mapper.getItemType()", hLine
		super hLine     # sets 'prefix' and 'str' for strings

		{line, str} = hLine

		if isString(line)
			assert isString(str), "str is #{OL(str)}"

			for type in @lSpecials
				recognizer = @hSpecials[type].recognizer
				if recognizer.bind(this)(str, hLine)
					debug "return from getItemType()", type
					return type

		debug "return from getItemType()", undef
		return undef

	# ..........................................................

	handleItemType: (type, hLine) ->

		debug "enter Mapper.handleItemType()", type, hLine
		assert defined(hLine), "hLine is undef"
		handler = @hSpecials[type].handler.bind(this)
		assert isFunction(handler), "Unknown type #{OL(type)}"

		uobj = handler(hLine)
		debug "return from Mapper.handleItemType()", uobj
		return uobj

	# ..........................................................

	isEmptyLine: (str, hLine) ->

		return (str == '')

	# ..........................................................

	isComment: (str, hLine) ->

		if lMatches = str.match(///^
				\s*
				\#      # a hash character
				(?:
					\s+
					(.*)
					)?
				$///)
			[_, comment] = lMatches
			hLine.comment = comment
			return true
		else
			return false

	# ..........................................................

	isCmd: (str, hLine) ->

		debug "enter Mapper.isCmd()"
		if lMatches = str.match(///^
				\#
				([A-Za-z_]\w*)   # name of the command
				\s*
				(.*)             # argstr for command
				$///)
			[_, cmd, argstr] = lMatches
			hLine.cmd = cmd
			hLine.argstr = argstr
			flag = true
		else
			# --- not a command
			flag = false

		debug "return from Mapper.isCmd()", flag
		return flag

	# ..........................................................

	handleEmptyLine: (hLine) ->
		# --- can override
		#     line may contain whitespace

		# --- return '' to keep empty lines
		return undef

	# ..........................................................

	handleComment: (hLine) ->

		debug "in Mapper.handleComment()"

		# --- return undef to remove comments
		return hLine.line

	# ..........................................................
	# --- handleCmd returns a mapped object, or
	#        undef to produce no output
	# Override must 1st handle its own commands,
	#    then call the base class handleCmd

	handleCmd: (hLine) ->

		debug "enter Mapper.handleCmd()", hLine

		# --- isCmd() put these keys here
		{cmd, argstr} = hLine

		# --- Each case should return
		switch cmd

			when 'define'
				if lMatches = argstr.match(///^
						(env\.)?
						([A-Za-z_][\w\.]*)   # name of the variable
						(.*)
						$///)
					[_, isEnv, name, tail] = lMatches
					if tail
						tail = tail.trim()
					if isEnv
						debug "set env var #{name} to '#{tail}'"
						process.env[name] = tail
					else
						debug "set var #{name} to '#{tail}'"
						@setConst name, tail

				debug "return from Mapper.handleCmd()", undef
				return undef

			else
				croak "Unknown command: ##{cmd}"

		croak "Not all cases return"

# ===========================================================================

export doMap = (inputClass, source, content=undef, hOptions={}) ->
	# --- Valid options:
	#        logLines

	debug "enter doMap()", inputClass, source, content
	assert inputClass?, "Missing input class"
	oInput = new inputClass(source, content)
	assert oInput instanceof Mapper,
		"doMap() requires a Mapper or subclass"
	debug "got oInput object"
	result = oInput.getBlock(hOptions)
	debug "return from doMap()", result
	return result
