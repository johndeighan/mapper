# Mapper.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, OL, rtrim, defined, escapeStr, className,
	isString, isHash, isArray, isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {splitPrefix, splitLine} from '@jdeighan/coffee-utils/indent'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'

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
	# --- override

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
				croak "Unknown cmd: #{OL(cmd)}"

# ===========================================================================

export doMap = (inputClass, source, content=undef, hOptions={}) ->
	# --- Valid options:
	#        logLines

	if isArray(inputClass)
		for cls,i in inputClass
			if i==0
				result = doMap cls, source, content, hOptions
			else
				result = doMap cls, source, result, hOptions
		return result

	debug "enter doMap()", inputClass, source, content
	assert inputClass?, "Missing input class"
	oInput = new inputClass(source, content)
	assert oInput instanceof Mapper, "Mapper or subclass required"
	debug "got oInput object"
	result = oInput.getBlock(hOptions)
	debug "return from doMap()", result
	return result
