# Mapper.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, OL, rtrim, defined, escapeStr, className,
	isString, isHash, isArray, isFunction, isIterable,
	isEmpty, nonEmpty, isSubclassOf,
	} from '@jdeighan/coffee-utils'
import {splitPrefix, splitLine} from '@jdeighan/coffee-utils/indent'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'
import {parseSource, slurp} from '@jdeighan/coffee-utils/fs'

import {Node} from '@jdeighan/mapper/node'
import {Getter} from '@jdeighan/mapper/getter'

# ---------------------------------------------------------------------------

export class Mapper extends Getter
	# --- handles #define
	#     performs const substitution
	#     splits mapping into special lines and non-special lines

	constructor: (source=undef, collection=undef) ->

		debug "enter Mapper()"
		super source, collection

		# --- These never change
		@setConst 'FILE', @hSourceInfo.filename
		@setConst 'DIR', @hSourceInfo.dir
		@setConst 'SRC', @sourceInfoStr()

		# --- This needs to be kept updated
		@setConst 'LINE', @lineNum

		@hSpecials = {}
		@lSpecials = []    # checked in this order

		# --- These must be bound to a specific object when called
		@registerSpecialType 'empty',   @isEmptyLine, @mapEmptyLine
		@registerSpecialType 'comment', @isComment, @mapComment
		@registerSpecialType 'cmd',     @isCmd, @mapCmd

		debug "return from Mapper()"

	# ..........................................................

	registerSpecialType: (type, recognizer, mapper) ->

		if ! @lSpecials.includes(type)
			@lSpecials.push(type)
		@hSpecials[type] = {
			recognizer
			mapper
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

	getItemType: (hNode) ->

		debug "enter Mapper.getItemType()", hNode
		{str} = hNode

		assert isString(str), "str is #{OL(str)}"
		for type in @lSpecials
			recognizer = @hSpecials[type].recognizer
			if recognizer.bind(this)(hNode)
				debug "return from getItemType()", type
				return type

		debug "return from getItemType()", undef
		return undef

	# ..........................................................

	mapSpecial: (type, hNode) ->

		debug "enter Mapper.mapSpecial()", type, hNode
		assert (hNode instanceof Node), "hNode is #{OL(hNode)}"
		assert (hNode.type == type), "hNode is #{OL(hNode)}"
		h = @hSpecials[type]
		assert isHash(h), "Unknown type #{OL(type)}"
		mapper = h.mapper.bind(this)
		assert isFunction(mapper), "Bad mapper for #{OL(type)}"
		uobj = mapper(hNode)
		debug "return from Mapper.mapSpecial()", uobj
		return uobj

	# ..........................................................

	isEmptyLine: (hNode) ->

		return (hNode.str == '')

	# ..........................................................

	mapEmptyLine: (hNode) ->

		# --- default: remove empty lines
		#     return '' to keep empty lines
		return undef

	# ..........................................................

	isComment: (hNode) ->

		if (hNode.str.indexOf('# ') == 0)
			hNode.uobj = {
				comment: hNode.str.substring(2).trim()
				}
			return true
		else
			return false

	# ..........................................................

	mapComment: (hNode) ->

		# --- default: remove comments
		# --- To keep comments, simply return hNode.uobj
		return undef

	# ..........................................................

	isCmd: (hNode) ->

		debug "enter Mapper.isCmd()"
		if lMatches = hNode.str.match(///^
				\#
				([A-Za-z_]\w*)   # name of the command
				\s*
				(.*)             # argstr for command
				$///)
			hNode.uobj = {
				cmd: lMatches[1]
				argstr: lMatches[2]
				}
			debug "return true from Mapper.isCmd()"
			return true
		else
			debug "return false from Mapper.isCmd()"
			return false

	# ..........................................................
	# --- mapCmd returns a mapped object, or
	#        undef to produce no output
	# Override must 1st handle its own commands,
	#    then call the base class mapCmd

	mapCmd: (hNode) ->

		debug "enter Mapper.mapCmd()", hNode

		# --- isCmd() put these keys here
		{cmd, argstr} = hNode.uobj
		assert nonEmpty(cmd), "mapCmd() with empty cmd"
		switch cmd
			when 'define'
				lMatches = argstr.match(///^
						(env\.)?
						([A-Za-z_][\w\.]*)   # name of the variable
						(.*)
						$///)
				assert defined(lMatches), "Bad #define cmd: #{cmd} #{argstr}"
				[_, isEnv, name, tail] = lMatches
				if tail
					tail = tail.trim()
				if isEnv
					debug "set env var #{name} to '#{tail}'"
					process.env[name] = tail
				else
					debug "set var #{name} to '#{tail}'"
					@setConst name, tail
				debug "return undef from Mapper.mapCmd()"
				return undef

			else
				# --- don't throw exception
				#     check for unknown commands in visitCmd()
				debug "return from Mapper.mapCmd()", hNode.uobj
				return hNode.uobj

	# ..........................................................

	containedText: (hNode, inlineText) ->
		# --- has side effect of fetching all indented text

		debug "enter Mapper.containedText()", hNode, inlineText
		{srcLevel} = hNode

		stopFunc = (h) ->
			return nonEmpty(h.str) && (h.srcLevel <= srcLevel)
		indentedText = @fetchBlockUntil(stopFunc, 'keepEndLine')

		debug "inline text", inlineText
		debug "indentedText", indentedText
		assert isEmpty(inlineText) || isEmpty(indentedText),
			"node #{OL(hNode)} has both inline text and indented text"

		if nonEmpty(indentedText)
			result = indentedText
		else if isEmpty(inlineText)
			result = ''
		else
			result = inlineText
		debug "return from containedText()", result
		return result

# ===========================================================================

export class FuncMapper extends Mapper

	constructor: (source=undef, collection=undef, @func) ->

		super(source, collection)
		assert isFunction(@func), "3rd arg not a function"

	getBlock: (hOptions={}) ->

		block = super(hOptions)
		return @func(block)

# ===========================================================================

export map = (source, content=undef, mapper, hOptions={}) ->
	# --- Valid options:
	#        logLines

	if isArray(mapper)
		result = content
		for item in mapper
			if defined(item)
				result = map(source, result, item, hOptions)
		return result

	debug "enter map()", source, content, mapper
	assert defined(mapper), "Missing input class"
	if (mapper instanceof Mapper)
		result = mapper.getBlock(hOptions)
	else if isSubclassOf(mapper, Mapper)
		mapper = new mapper(source, content)
		assert (mapper instanceof Mapper), "Mapper or subclass required"
		result = mapper.getBlock(hOptions)
	else
		croak "Bad mapper"
	debug "return from map()", result
	return result

# ---------------------------------------------------------------------------
