# Getter.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn, dbgYield, dbgResume,
	} from '@jdeighan/base-utils/debug'
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

		dbgEnter "Getter.get"

		while defined(hNode = @fetch())
			dbg "GOT", hNode
			assert (hNode instanceof Node), "hNode is #{OL(hNode)}"
			level = hNode.level

			# --- check for extension lines (only if str non-empty)
			str = hNode.str
			if nonEmpty(str)
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
				dbg "newly mapped"
				dbgReturn "Getter.get", hNode
				return hNode

		dbg "EOF"
		dbgReturn "Getter.get", undef
		return undef

	# ..........................................................

	extSep: (str, nextStr) ->

		return ' '

	# ..........................................................

	skip: () ->

		dbgEnter 'Getter.skip'
		@get()
		dbgReturn 'Getter.skip'
		return

	# ..........................................................

	peek: () ->

		dbgEnter 'Getter.peek'
		hNode = @get()
		if (hNode == undef)
			dbgReturn "Getter.peek", undef
			return undef
		else
			@unfetch hNode
			dbgReturn "Getter.peek", hNode
			return hNode

	# ..........................................................

	eof: () ->

		dbgEnter "Getter.eof"

		result = (@peek() == undef)
		dbgReturn "Getter.eof", result
		return result

	# ..........................................................
	# --- return of undef doesn't mean EOF, it means skip this item
	#     sets key 'uobj' to a defined value if not returning undef
	#     sets key 'type' if a special type

	mapAnyNode: (hNode) ->

		dbgEnter "Getter.mapAnyNode", hNode
		assert defined(hNode), "hNode is undef"

		type = @getItemType(hNode)
		if defined(type)
			dbg "item type is #{OL(type)}"
			assert isString(type) && nonEmpty(type), "bad type: #{OL(type)}"
			hNode.type = type
			uobj = @mapSpecial(type, hNode)
			dbg "mapped #{type}", uobj
		else
			dbg "no special type"
			{str, level} = hNode
			assert defined(str), "str is undef"
			assert (str != '__END__'), "__END__ encountered"
			newstr = @replaceConsts(str, @hConsts)
			if (newstr != str)
				dbg "#{OL(str)} => #{OL(newstr)}"
				hNode.str = newstr

			uobj = @mapNonSpecial(hNode)
			dbg "mapped non-special", uobj

		dbgReturn "Getter.mapAnyNode", uobj
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

		dbg "in Getter.getItemType()"
		return undef   # default: no special item types

	# ..........................................................
	# --- GENERATOR

	allMapped: () ->

		dbgEnter "Getter.allMapped"

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(hNode = @get())
			dbg "GOT", hNode
			dbgYield 'Getter.allMapped', hNode
			yield hNode
			dbgResume 'Getter.allMapped'
		dbgReturn "Getter.allMapped"
		return

	# ..........................................................
	# --- GENERATOR

	allMappedUntil: (func, endLineOption) ->

		dbgEnter "Getter.allMappedUntil"

		assert isFunction(func), "Arg 1 not a function"
		assert (endLineOption=='keepEndLine') \
			|| (endLineOption=='discardEndLine'),
			"bad end line option: #{OL(endLineOption)}"

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(hNode = @get()) && ! func(hNode)
			dbg "GOT", hNode
			dbgYield "Getter.allMappedUntil", hNode
			yield hNode
			dbgResume "Getter.allMappedUntil"
		if defined(hNode) && (endLineOption=='keepEndLine')
			@unfetch hNode

		dbgReturn "Getter.allMappedUntil"
		return

	# ..........................................................

	getAll: () ->

		dbgEnter "Getter.getAll"
		lNodes = Array.from(@allMapped())
		dbgReturn "Getter.getAll", lNodes
		return lNodes

	# ..........................................................

	getUntil: (func, endLineOption) ->

		dbgEnter "Getter.getUntil"
		assert isFunction(func), "not a function"
		assert (endLineOption=='keepEndLine') \
			|| (endLineOption=='discardEndLine'),
			"bad end line option: #{OL(endLineOption)}"
		lNodes = Array.from(@allMappedUntil(func, endLineOption))
		dbgReturn "Getter.getUntil", lNodes
		return lNodes

	# ..........................................................
	# --- Rarely used - requires that uobj's are strings
	#     TreeMapper overrides this, and is more commonly used

	getBlock: (hOptions={}) ->
		# --- Valid options: logNodes

		dbgEnter "Getter.getBlock"
		lStrings = []
		i = 0
		for hNode from @allMapped()
			if hOptions.logNodes
				LOG "hNode[#{i}]", hNode
			else
				dbg "hNode[#{i}]", hNode
			i += 1

			# --- default visit() & visitSpecial() return uobj

			if (hNode.type == undef)
				result = @visit(hNode)
			else
				result = @visitSpecial(hNode.type, hNode)

			if defined(result)
				assert isString(result), "not a string"
				lStrings.push result

		dbg 'lStrings', lStrings
		if defined(endStr = @endBlock())
			dbg 'endStr', endStr
			lStrings.push endStr

		if hOptions.logNodes
			LOG 'logNodes', lStrings

		block = @finalizeBlock(arrayToBlock(lStrings))
		dbgReturn "Getter.getBlock", block
		return block

	# ..........................................................

	visit: (hNode) ->

		dbgEnter "Getter.visit", hNode
		{uobj} = hNode
		if isString(uobj)
			dbgReturn "Getter.visit", uobj
			return uobj
		else if defined(uobj)
			croak "uobj #{OL(uobj)} should be a string"
		else
			dbgReturn "Getter.visit", undef
			return undef

	# ..........................................................

	visitSpecial: (type, hNode) ->

		dbgEnter "Getter.visitSpecial", type, hNode
		{uobj} = hNode
		if isString(uobj)
			dbgReturn "Getter.visitSpecial", uobj
			return uobj
		else if defined(uobj)
			croak "uobj #{OL(uobj)} should be a string"
		else
			dbgReturn "Getter.visitSpecial", undef
			return undef

	# ..........................................................

	endBlock: () ->
		# --- currently, only used in markdown processing

		return undef

	# ..........................................................

	finalizeBlock: (block) ->

		return block
