# Getter.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, OL, rtrim, defined, notdefined,
	escapeStr, isString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {arrayToBlock, blockToArray} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'

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
			if hNode.isMapped()
				# --- This can happen when the node was previously unfetched
				debug "return from Getter.get() - already mapped", hNode
				return hNode
			uobj = @mapNode(hNode)
			if defined(uobj)
				hNode.uobj = uobj
				debug "return from Getter.get() - newly mapped", hNode
				return hNode

		debug "return from Getter.get() - EOF", undef
		return undef

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

	mapNode: (hNode) ->

		debug "enter Getter.mapNode()", hNode
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

		debug "return from Getter.mapNode()", uobj
		return uobj

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

	mapSpecial: (type, hNode) ->

		# --- default - ignore any special item types
		#     - but by default, there aren't any!
		return undef

	# ..........................................................
	# --- designed to override
	#     override may use fetch(), unfetch(), fetchBlock(), etc.
	#     should return a uobj (undef to ignore line)

	mapNonSpecial: (hNode) ->
		# --- returns a uobj or undef
		#     uobj will be passed to visit() and endVisit() in TreeWalker

		debug "enter Getter.mapNonSpecial()", hNode
		assert defined(hNode), "hNode is undef"

		uobj = @map(hNode)
		debug "return from Getter.mapNonSpecial()", uobj
		return uobj

	# ..........................................................
	# --- designed to override

	map: (hNode) ->

		# --- by default, just returns str key indented
		{str, level} = hNode
		return indented(str, level, @oneIndent)

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

	allMappedUntil: (func, hOptions=undef) ->

		debug "enter Getter.allMappedUntil()"

		assert isFunction(func), "Arg 1 not a function"
		if defined(hOptions)
			discardEndLine = hOptions.discardEndLine
		else
			discardEndLine = true

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(hNode = @get()) && ! func(hNode)
			debug "GOT", hNode
			yield hNode
		if defined(hNode) && ! discardEndLine
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

	getUntil: (func, hOptions=undef) ->

		debug "enter Getter.getUntil()"

		lNodes = Array.from(@allMappedUntil(func, hOptions))
		debug "return from Getter.getUntil()", lNodes
		return lNodes

	# ..........................................................
	# --- Rarely used - requires that uobj's are strings
	#     TreeWalker overrides this, and is more commonly used

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

			lStrings.push hNode.uobj

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

	endBlock: () ->
		# --- currently, only used in markdown processing

		return undef

	# ..........................................................

	finalizeBlock: (block) ->

		return block
