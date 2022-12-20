# Mapper.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {
	undef, pass, OL, rtrim, defined, escapeStr, className,
	isString, isHash, isArray, isFunction, isIterable, isObject,
	isEmpty, nonEmpty, isSubclassOf, isConstructor,
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

	constructor: (hInput, options={}) ->

		dbgEnter "Mapper", hInput, options
		super hInput, options

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

		dbgEnter "Mapper.incLineNum", inc
		super inc
		@setConst 'LINE', @lineNum
		dbgReturn "Mapper.incLineNum"
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
		indentedText = @getBlockUntil(stopFunc, 'keepEndLine')

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
		dbgReturn "Mapper.containedText", result
		return result

# ===========================================================================

export class FuncMapper extends Mapper

	constructor: (hInput, @func) ->

		super(hInput)
		assert isFunction(@func), "3rd arg not a function"

	getBlock: (hOptions={}) ->

		block = super(hOptions)
		return @func(block)

# ===========================================================================
# --- arg mapper must be a subclass of Mapper or an array
#     of subclasses of Mapper. If you have a function to do
#     a mapping, pass in new FuncMapper(func)

export map = (hInput, mapper, hOptions={}) ->
	# --- Valid options:
	#        logNodes

	dbgEnter "map", hInput, mapper, hOptions

	# --- This shouldn't be necessary
	#     ...BUT it should work

	if isString(hInput)
		dbg "hInput is a string, constructing new hInput"
		hInput = {content: hInput}

	# --- An array can be provided - the input is processed
	#     by each array element sequentially
	if isArray(mapper)
		dbg "mapper is an array - using each array element"
		for item in mapper
			if defined(item)
				hInput.content = map(hInput, item, hOptions)
		dbgReturn "map", hInput.content
		return hInput.content

	assert isHash(hInput), "hInput not a hash: #{OL(hInput)}"
	{source, content} = hInput
	dbg "unpacked:"
	dbg '   source =', source
	dbg '   content =', content
	assert defined(mapper), "Missing mapper"

	# --- mapper can be an object, which is an instance of Mapper
	#     or it can just be a class which, when instantiated
	#     has a getBlock() method

	if isObject(mapper, '&getBlock')
		dbg "mapper is object, calling its getBlock()"
		result = mapper.getBlock(hOptions)
	else if isConstructor(mapper)
		dbg "mapper is constructor, creating instance"
		dbg 'source =', source
		dbg 'content =', content
		obj = new mapper({source, content})
		assert isObject(obj, '&getBlock'), 'object has no getBlock method'
		result = obj.getBlock(hOptions)
	else if isFunction(mapper)
		dbg "mapper is a function, calling it"
		if notdefined(content)
			assert defined(source), "Neither source nor content defined"
			content = slurp(source)
		result = mapper(content)
	else
		croak "Bad mapper in map(): #{OL(mapper)}"
	dbgReturn "map", result
	return result
