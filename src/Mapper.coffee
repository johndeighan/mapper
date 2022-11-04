# Mapper.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {dbg, dbgEnter, dbgReturn} from '@jdeighan/base-utils/debug'
import {
	undef, pass, OL, rtrim, defined, escapeStr, className,
	isString, isHash, isArray, isFunction, isIterable,
	isEmpty, nonEmpty, isSubclassOf,
	} from '@jdeighan/coffee-utils'
import {splitPrefix, splitLine} from '@jdeighan/coffee-utils/indent'
import {parseSource, slurp} from '@jdeighan/coffee-utils/fs'

import {Node} from '@jdeighan/mapper/node'
import {Getter} from '@jdeighan/mapper/getter'

# ---------------------------------------------------------------------------

export class Mapper extends Getter
	# --- handles #define
	#     performs const substitution
	#     splits mapping into special lines and non-special lines

	constructor: (source=undef, collection=undef) ->

		dbgEnter "Mapper"
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

		dbgReturn "Mapper"

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

		dbgEnter "incLineNum", inc
		super inc
		@setConst 'LINE', @lineNum
		dbgReturn "incLineNum"
		return

	# ..........................................................

	getItemType: (hNode) ->

		dbgEnter "Mapper.getItemType", hNode
		{str} = hNode

		assert isString(str), "str is #{OL(str)}"
		for type in @lSpecials
			recognizer = @hSpecials[type].recognizer
			if recognizer.bind(this)(hNode)
				dbgReturn "Mapper.getItemType", type
				return type

		dbgReturn "Mapper.getItemType", undef
		return undef

	# ..........................................................

	mapSpecial: (type, hNode) ->

		dbgEnter "Mapper.mapSpecial", type, hNode
		assert (hNode instanceof Node), "hNode is #{OL(hNode)}"
		assert (hNode.type == type), "hNode is #{OL(hNode)}"
		h = @hSpecials[type]
		assert isHash(h), "Unknown type #{OL(type)}"
		mapper = h.mapper.bind(this)
		assert isFunction(mapper), "Bad mapper for #{OL(type)}"
		uobj = mapper(hNode)
		dbgReturn "Mapper.mapSpecial", uobj
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

		dbgEnter "Mapper.isCmd"
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
			dbgReturn "Mapper.isCmd", true
			return true
		else
			dbgReturn "Mapper.isCmd", false
			return false

	# ..........................................................
	# --- mapCmd returns a mapped object, or
	#        undef to produce no output
	# Override must 1st handle its own commands,
	#    then call the base class mapCmd

	mapCmd: (hNode) ->

		dbgEnter "Mapper.mapCmd", hNode

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
					dbg "set env var #{name} to '#{tail}'"
					process.env[name] = tail
				else
					dbg "set var #{name} to '#{tail}'"
					@setConst name, tail
				dbgReturn "Mapper.mapCmd", undef
				return undef

			else
				# --- don't throw exception
				#     check for unknown commands in visitCmd()
				dbgReturn "Mapper.mapCmd", hNode.uobj
				return hNode.uobj

	# ..........................................................

	containedText: (hNode, inlineText) ->
		# --- has side effect of fetching all indented text

		dbgEnter "Mapper.containedText", hNode, inlineText
		{srcLevel} = hNode

		stopFunc = (h) ->
			return nonEmpty(h.str) && (h.srcLevel <= srcLevel)
		indentedText = @fetchBlockUntil(stopFunc, 'keepEndLine')

		dbg "inline text", inlineText
		dbg "indentedText", indentedText
		assert isEmpty(inlineText) || isEmpty(indentedText),
			"node #{OL(hNode)} has both inline text and indented text"

		if nonEmpty(indentedText)
			result = indentedText
		else if isEmpty(inlineText)
			result = ''
		else
			result = inlineText
		dbgReturn "containedText", result
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
	#        logNodes

	if isArray(mapper)
		result = content
		for item in mapper
			if defined(item)
				result = map(source, result, item, hOptions)
		return result

	dbgEnter "map", source, content, mapper
	assert defined(mapper), "Missing input class"

	# --- mapper can be an object, which is an instance of Mapper
	#     or it can just be a class which, when instantiated
	#     has a getBlock() method

	if (typeof mapper.getBlock == 'function')
		dbg "using mapper directly"
		result = mapper.getBlock(hOptions)
	else
		dbg "creating mapper instance"
		obj = new mapper(source, content)
		assert (typeof obj.getBlock == 'function'), "missing getBlock() method"
		result = obj.getBlock(hOptions)
	dbgReturn "map", result
	return result
