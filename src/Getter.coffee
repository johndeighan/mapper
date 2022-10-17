# Getter.coffee

import {LOG, debug, assert, croak} from '@jdeighan/exceptions'
import {
	undef, pass, OL, rtrim, defined, notdefined,
	escapeStr, isString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {arrayToBlock, blockToArray} from '@jdeighan/coffee-utils/block'

import {Node} from '@jdeighan/mapper/node'
import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------
#   class Getter
#      - get(), peek(), eof(), skip() for mapped data

export class Getter extends Fetcher

	constructor: (source=undef, collection=undef) ->

		super source, collection
		@hConsts = {}   # support variable replacement

	# ..........................................................

	setConst: (name, value) ->

		assert (name == 'LINE') || (@hConsts[name] == undef),
				"cannot set constant #{name} twice"
		@hConsts[name] = value
		return

	# ..........................................................

	getConst: (name) ->

		return @hConsts[name]

	# ..........................................................
	#        Mapped Data
	# ..........................................................

	get: () ->

		debug "enter Getter.get()"

		while defined(hNode = @fetch())
			debug "GOT", hNode
			assert (hNode instanceof Node), "hNode is #{OL(hNode)}"
			level = hNode.level

			# --- check for extension lines
			str = hNode.str
			while defined(hExt = @fetch()) \
					&& assert(hExt instanceof Node, "hExt = #{OL(hExt)}") \
					&& (hExt.level >= level + 2)
				extStr = hExt.str
				str += @extSep(str, extStr) + extStr
			if defined(hExt)
				@unfetch hExt
			hNode.str = str

			if hNode.notMapped()
				hNode.uobj = @mapAnyNode(hNode)
			if defined(hNode.uobj)
				debug "return from Getter.get() - newly mapped", hNode
				return hNode

		debug "return from Getter.get() - EOF", undef
		return undef

	# ..........................................................

	extSep: (str, nextStr) ->

		return ' '

	# ..........................................................

	skip: () ->

		debug 'enter Getter.skip():'
		@get()
		debug 'return from Getter.skip()'
		return

	# ..........................................................

	peek: () ->

		debug 'enter Getter.peek()'
		hNode = @get()
		if (hNode == undef)
			debug "return from Getter.peek()", undef
			return undef
		else
			@unfetch hNode
			debug "return from Getter.peek()", hNode
			return hNode

	# ..........................................................

	eof: () ->

		debug "enter Getter.eof()"

		result = (@peek() == undef)
		debug "return from Getter.eof()", result
		return result

	# ..........................................................
	# --- return of undef doesn't mean EOF, it means skip this item
	#     sets key 'uobj' to a defined value if not returning undef
	#     sets key 'type' if a special type

	mapAnyNode: (hNode) ->

		debug "enter Getter.mapAnyNode()", hNode
		assert defined(hNode), "hNode is undef"

		type = @getItemType(hNode)
		if defined(type)
			debug "item type is #{OL(type)}"
			assert isString(type) && nonEmpty(type), "bad type: #{OL(type)}"
			hNode.type = type
			uobj = @mapSpecial(type, hNode)
			debug "mapped #{type}", uobj
		else
			debug "no special type"
			{str, level} = hNode
			assert defined(str), "str is undef"
			assert (str != '__END__'), "__END__ encountered"
			newstr = @replaceConsts(str, @hConsts)
			if (newstr != str)
				debug "#{OL(str)} => #{OL(newstr)}"
				hNode.str = newstr

			uobj = @mapNonSpecial(hNode)
			debug "mapped non-special", uobj

		debug "return from Getter.mapAnyNode()", uobj
		return uobj

	# ..........................................................

	mapSpecial: (type, hNode) ->

		# --- default - ignore any special item types
		#     - but by default, there aren't any!
		return undef

	# ..........................................................

	mapNonSpecial: (hNode) ->
		# --- TreeMapper overrides this

		return @mapNode(hNode)

	# ..........................................................
	# --- designed to override
	#     only non-special nodes

	mapNode: (hNode) ->

		# --- by default, just returns str key indented
		{str, level} = hNode
		return indented(str, level, @oneIndent)

	# ..........................................................

	replaceConsts: (str, hVars={}) ->

		assert isHash(hVars), "hVars is not a hash"

		replacerFunc = (match, prefix, name) =>
			if prefix
				return process.env[name]
			else
				value = hVars[name]
				if defined(value)
					if isString(value)
						return value
					else
						return JSON.stringify(value)
				else
					return "__#{name}__"

		return str.replace(///
				__
				(env\.)?
				([A-Za-z_][A-Za-z0-9_]*)
				__
				///g, replacerFunc)

	# ..........................................................

	getItemType: (hNode) ->
		# --- returns name of item type

		debug "in Getter.getItemType()"
		return undef   # default: no special item types

	# ..........................................................
	# --- GENERATOR

	allMapped: () ->

		debug "enter Getter.allMapped()"

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(hNode = @get())
			debug "GOT", hNode
			yield hNode
		debug "return from Getter.allMapped()"
		return

	# ..........................................................
	# --- GENERATOR

	allMappedUntil: (func, endLineOption) ->

		debug "enter Getter.allMappedUntil()"

		assert isFunction(func), "Arg 1 not a function"
		assert (endLineOption=='keepEndLine') \
			|| (endLineOption=='discardEndLine'),
			"bad end line option: #{OL(endLineOption)}"

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(hNode = @get()) && ! func(hNode)
			debug "GOT", hNode
			yield hNode
		if defined(hNode) && (endLineOption=='keepEndLine')
			@unfetch hNode

		debug "return from Getter.allMappedUntil()"
		return

	# ..........................................................

	getAll: () ->

		debug "enter Getter.getAll()"
		lNodes = Array.from(@allMapped())
		debug "return from Getter.getAll()", lNodes
		return lNodes

	# ..........................................................

	getUntil: (func, endLineOption) ->

		debug "enter Getter.getUntil()"
		assert isFunction(func), "not a function"
		assert (endLineOption=='keepEndLine') \
			|| (endLineOption=='discardEndLine'),
			"bad end line option: #{OL(endLineOption)}"
		lNodes = Array.from(@allMappedUntil(func, endLineOption))
		debug "return from Getter.getUntil()", lNodes
		return lNodes

	# ..........................................................
	# --- Rarely used - requires that uobj's are strings
	#     TreeMapper overrides this, and is more commonly used

	getBlock: (hOptions={}) ->
		# --- Valid options: logNodes

		debug "enter Getter.getBlock()"
		lStrings = []
		i = 0
		for hNode from @allMapped()
			if hOptions.logNodes
				LOG "hNode[#{i}]", hNode
			else
				debug "hNode[#{i}]", hNode
			i += 1

			# --- default visit() & visitSpecial() return uobj

			if (hNode.type == undef)
				result = @visit(hNode)
			else
				result = @visitSpecial(hNode.type, hNode)

			if defined(result)
				assert isString(result), "not a string"
				lStrings.push result

		debug 'lStrings', lStrings
		if defined(endStr = @endBlock())
			debug 'endStr', endStr
			lStrings.push endStr

		if hOptions.logNodes
			LOG 'logNodes', lStrings

		block = @finalizeBlock(arrayToBlock(lStrings))
		debug "return from Getter.getBlock()", block
		return block

	# ..........................................................

	visit: (hNode) ->

		debug "enter Getter.visit()", hNode
		{uobj} = hNode
		if isString(uobj)
			debug "return from Getter.visit()", uobj
			return uobj
		else if defined(uobj)
			croak "uobj #{OL(uobj)} should be a string"
		else
			debug "return undef from Getter.visit()"
			return undef

	# ..........................................................

	visitSpecial: (type, hNode) ->

		debug "enter Getter.visitSpecial()", type, hNode
		{uobj} = hNode
		if isString(uobj)
			debug "return from Getter.visitSpecial()", uobj
			return uobj
		else if defined(uobj)
			croak "uobj #{OL(uobj)} should be a string"
		else
			debug "return undef from Getter.visitSpecial()"
			return undef

	# ..........................................................

	endBlock: () ->
		# --- currently, only used in markdown processing

		return undef

	# ..........................................................

	finalizeBlock: (block) ->

		return block
