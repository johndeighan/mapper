# Getter.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn,
	dbgYield, dbgResume,
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
#   class Getter - get() for mapped data

export class Getter extends Fetcher

	constructor: (hInput, options={}) ->

		super hInput, options
		@hConsts = {}   # support variable replacement

	# ..........................................................

	setConst: (name, value) ->

		# --- Only const LINE can be redefined
		assert (name == 'LINE') || notdefined(@hConsts[name]),
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
		# --- Return of undef indicates no more data
		#     But, if mapAnyNode() returns undef, that just means
		#        to skip this node - not necessarily end of file

		dbgEnter "Getter.get"

		while hNode = @fetch()
			uobj = @mapAnyNode(hNode)
			if defined(uobj)
				hNode.uobj = uobj
				dbgReturn "Getter.get", hNode
				return hNode

		dbg "EOF"
		dbgReturn "Getter.get", undef
		return undef

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

	all: () ->

		dbgEnter "Getter.all"

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(hNode = @get())
			dbgYield 'Getter.all', hNode
			yield hNode
			dbgResume 'Getter.all'
		dbgReturn "Getter.all"
		return

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
