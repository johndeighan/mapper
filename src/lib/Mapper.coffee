# Mapper.coffee

import {
	undef, pass, OL, rtrim, defined, notdefined,
	escapeStr, isHashComment, getOptions,
	isString, isHash, isArray, isFunction, isIterable, isObject,
	isEmpty, nonEmpty, isClass, className,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {fromTAML} from '@jdeighan/base-utils/taml'
import {splitPrefix, splitLine} from '@jdeighan/base-utils/indent'

import {Node} from '@jdeighan/mapper/node'
import {Getter} from '@jdeighan/mapper/getter'

# ---------------------------------------------------------------------------
# class Mapper - adds:
#    1. registering special types of nodes, by default:
#          - empty lines
#          - comments
#          - commands
#    2. defines constants FILE, DIR and SRC
#    3. implements command #define

export class Mapper extends Getter

	constructor: (hInput, options={}) ->

		dbgEnter "Mapper", hInput, options
		super hInput, options

		# --- These never change
		@setConst 'FILE', @hSourceInfo.fileName
		@setConst 'DIR',  @hSourceInfo.dir
		@setConst 'SRC',  @sourceInfoStr()

		@hSpecials = {}
		@lSpecials = []    # checked in this order

		# --- These must be bound to a specific object when called
		@registerType 'empty',   @isEmptyLine, @mapEmptyLine
		@registerType 'comment', @isComment,   @mapComment
		@registerType 'cmd',     @isCmd,       @mapCmd

		dbgReturn "Mapper"

	# ..........................................................

	isValidType: (type) ->

		return defined(@hSpecials[type])

	# ..........................................................

	registerType: (type, recognizer, mapper) ->

		if ! @lSpecials.includes(type)
			@lSpecials.push(type)
		@hSpecials[type] = {
			recognizer
			mapper
			}
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

	mapNode: (hNode) ->

		dbgEnter "Mapper.mapNode", hNode
		assert (hNode instanceof Node), "hNode is #{OL(hNode)}"
		{type} = hNode
		if type
			h = @hSpecials[type]
			assert isHash(h), "Unknown type #{OL(type)}"
			mapper = h.mapper.bind(this)
			assert isFunction(mapper), "Bad mapper for #{OL(type)}"
			uobj = mapper(hNode)
		else
			uobj = @mapToUserObj(hNode)
		dbgReturn "Mapper.mapNode", uobj
		return uobj

	# ..........................................................
	# designed to override
	# only receives nodes without a type

	mapToUserObj: (hNode) ->

		{type, str} = hNode
		assert notdefined(type), "mapToUserObj(): type = #{type}"
		return str

	# ==========================================================

	isEmptyLine: (hNode) ->

		return (hNode.str == '')

	# ..........................................................

	mapEmptyLine: (hNode) ->

		# --- default: remove empty lines
		#     return '' to keep empty lines
		return undef

	# ==========================================================

	isComment: (hNode) ->

		hInfo = isHashComment(hNode.str)
		if defined(hInfo)
			hNode._commentText = hInfo.text
			return true
		else
			return false

	# ..........................................................

	mapComment: (hNode) ->

		# --- default: remove comments
		# --- To keep comments, return "# #{hNode._commentText}"
		return undef

	# ==========================================================

	isCmd: (hNode) ->

		dbgEnter "Mapper.isCmd"
		if defined(lMatches = hNode.str.match(///^
				\#
				([A-Za-z_]\w*)   # name of the command
				\s*
				(.*)             # argstr for command
				$///))
			[_, cmd, argstr] = lMatches
			assert (cmd != 'include'), "#include found!"
			hNode.uobj = {cmd, argstr}
			result = true
		else
			result = false
		dbgReturn "Mapper.isCmd", result
		return result

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
				croak "Unknown command: #{OL(cmd)}"

				# --- don't throw exception
				#     check for unknown commands in visitCmd()
#				dbgReturn "Mapper.mapCmd", hNode.uobj
#				return hNode.uobj

# ===========================================================================
# --- mapperClass must be a subclass of Mapper or an array
#     of subclasses of Mapper.

export map = (input, mapperClass=Mapper, hOptions={}) ->

	dbgEnter "map", input, mapperClass, hOptions

	hOptions = getOptions hOptions, {
		as: 'block',
		oneIndent: '\t'
		}

	# --- Valid options:
	#        as: ('block' | 'lines')
	#        oneIndent: <string>  default: TAB

	# --- mapperClass can be an array - the input is processed
	#     by each array element sequentially
	if isArray(mapperClass)
		dbg "mapperClass is an array - using each array element"

		content = input
		dbg 'original content', content
		for item in mapperClass
			if defined(item)
				content = map(content, item, hOptions)
				dbg 'new content', content
		dbgReturn "map", content
		return content

	assert isClass(mapperClass), "mapper not a constructor"

	mapper = new mapperClass(input)
	assert (mapper instanceof Mapper), "not a Mapper instance"
	switch hOptions.as
		when 'block'
			result = mapper.getBlock(hOptions.oneIndent)
		when 'lines'
			result = mapper.getLines(hOptions)
		else
			croak "option 'as' must be 'block' or 'lines'"
	dbgReturn "map", result
	return result
