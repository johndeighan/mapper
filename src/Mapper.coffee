# Mapper.coffee

import {
	assert, undef, pass, croak, OL, rtrim, defined, escapeStr, className,
	isString, isHash, isArray, isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Getter} from '@jdeighan/mapper/getter'

# ---------------------------------------------------------------------------
#   class Mapper
#       handles:
#          #define
#          const replacement

export class Mapper extends Getter

	constructor: (source=undef, collection=undef, hOptions={}) ->

		debug "enter Mapper()"
		super source, collection, hOptions

		@setConst 'FILE', @filename
		@setConst 'DIR', @hSourceInfo.dir
		@setConst 'LINE', @lineNum
		debug "return from Mapper()"

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

	getItemType: (item) ->

		debug "enter Mapper.getItemType()", item

		# --- only strings may have an item type
		if isString(item)

			# --- check for empty item
			if @isEmptyLine(item)
				result = ['empty', undef]

			# --- check for comment
			else if @isComment(item)
				result = ['comment', undef]

			# --- check for cmd
			else if defined(h = @isCmd(item))
				assert isHash(h, ['cmd','argstr','prefix']),
						"isCmd() returned non-hash #{OL(h)}"
				result = ['cmd', h]

		if (result == undef)
			result = [undef, undef]

		debug "return from Mapper.getItemType()", result
		return result

	# ..........................................................
	# --- override

	handleItemType: (type, item, h) ->

		debug "enter Mapper.handleItemType(#{OL(type)})", item

		switch type
			when 'empty'
				uobj = @handleEmptyLine()
			when 'comment'
				uobj = @handleComment(item)
			when 'cmd'
				{cmd, argstr, prefix} = h
				assert isString(cmd), "cmd not a string"
				assert isString(argstr), "argstr not a string"
				assert isString(prefix), "prefix not a string"
				uobj = @handleCmd(cmd, argstr, prefix, h)
			else
				croak "Unknown item type: #{OL(type)}"

		debug "return from Mapper.handleItemType()", uobj
		return uobj

	# ..........................................................

	isEmptyLine: (line) ->

		return isEmpty(line)

	# ..........................................................

	handleEmptyLine: (line) ->
		# --- can override
		#     line may contain whitespace

		# --- return '' to keep empty lines
		return undef

	# ..........................................................

	isComment: (line) ->

		if (lMatches = line.match(///^
				\s*
				\#      # a # character
				(.|$)   # following character, if any
				///))
			ch = lMatches[1]
			return (ch == undef) || (ch in [' ','\t',''])
		else
			return false

	# ..........................................................

	handleComment: (line) ->

		debug "in Mapper.handleComment()"

		# --- return line to keep comments
		return undef

	# ..........................................................

	isCmd: (line) ->
		# --- Must return either undef or {prefix, cmd, argstr}

		debug "enter Mapper.isCmd()"
		if lMatches = line.match(///^
				(\s*)
				\#
				([A-Za-z_]\w*)   # name of the command
				\s*
				(.*)             # argstr for command
				$///)
			[_, prefix, cmd, argstr] = lMatches
			if !prefix
				prefix = ''
			hResult = {
				cmd
				argstr: if argstr then argstr.trim() else ''
				prefix
				}
			debug "return from Mapper.isCmd()", hResult
			return hResult

		# --- not a command
		debug "return undef from Mapper.isCmd()"
		return undef

	# ..........................................................
	# --- handleCmd returns a mapped object, or
	#        undef to produce no output
	# Override must 1st handle its own commands,
	#    then call the base class handleCmd

	handleCmd: (cmd, argstr, prefix, h) ->
		# --- h has keys 'cmd','argstr' and 'prefix'
		#     but may contain additional keys

		debug "enter Mapper.handleCmd ##{cmd} '#{argstr}'"
		assert isString(prefix), "prefix not a string"
		if (prefix.length > 0)
			debug "   prefix = '#{escapeStr(prefix)}'"

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

				debug "return undef from Mapper.handleCmd()"
				return undef

			else
				croak "Unknown command: ##{cmd}"

		croak "Not all cases return"

# ===========================================================================

export doMap = (inputClass, source, content=undef) ->

	assert inputClass?, "Missing input class"
	name = className(inputClass)
	debug "enter doMap()", name, source, content
	oInput = new inputClass(source, content)
	assert oInput instanceof Mapper,
		"doMap() requires a Mapper or subclass"
	debug "got oInput object"
	result = oInput.getBlock()
	debug "return from doMap()", result
	return result
