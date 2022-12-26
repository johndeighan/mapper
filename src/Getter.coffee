# Getter.coffee

import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	dbgYield, dbgResume,
	} from '@jdeighan/base-utils/debug'
import {
	undef, pass, OL, rtrim, defined, notdefined,
	escapeStr, isString, isNonEmptyString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {toBlock, toArray} from '@jdeighan/coffee-utils/block'

import {Node} from '@jdeighan/mapper/node'
import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------
#   class Getter - adds:
#      1. setConst() and getConst()
#      2. replacing constants in non-special lines, incl env vars
#            NOTE: does not implement #define
#      2. get() - fetch(), then determine node type and either:
#            - call mapSpecial()
#            - call mapNode()

export class Getter extends Fetcher

	constructor: (hInput, options={}) ->

		super hInput, options
		@hConsts = {}   # support constant replacement

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
		#        to skip this node - not necessarily EOF

		dbgEnter "Getter.get"

		if defined(@getStopperNode)
			save = @getStopperNode
			@getStopperNode = undef
			dbg "return stopper node"
			dbgReturn 'Getter.get', save
			return save

		while defined(hNode = @fetch())
			type = @getItemType(hNode)
			if defined(type)
				dbg "item type is type #{OL(type)}"
				assert isNonEmptyString(type), "bad type: #{OL(type)}"
				hNode.type = type
				uobj = @mapSpecial(type, hNode)   # might be undef
				dbg "mapped #{type}", uobj
			else
				dbg "no special type"
				{str, level} = hNode
				assert defined(str), "str is undef"
				assert (str != '__END__'), "__END__ encountered"
				newstr = @replaceConsts(str)
				if (newstr != str)
					dbg "#{OL(str)} => #{OL(newstr)}"
					hNode.str = newstr

				uobj = @mapNode(hNode)    # might be undef
				dbg "mapped non-special", uobj

			if defined(uobj)
				hNode.uobj = uobj
				dbgReturn "Getter.get", hNode
				return hNode

		dbg "EOF"
		dbgReturn "Getter.get", undef
		return undef

	# ..........................................................
	# --- designed to override

	getItemType: (hNode) ->
		# --- returns name of item type

		return undef   # default: no special item types

	# ..........................................................
	# --- designed to override
	#     return a uobj

	mapSpecial: (type, hNode) ->

		# --- default - ignore any special item types
		#     - but by default, there aren't any!
		return undef

	# ..........................................................
	# --- designed to override
	#     only called for non-special nodes
	#     return a uobj

	mapNode: (hNode) ->

		# --- by default, just returns str key
		return hNode.str

	# ..........................................................

	replaceConsts: (str) ->

		replacerFunc = (match, prefix, name) =>
			if prefix
				return process.env[name]
			else
				value = @hConsts[name]
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
	# --- GENERATOR

	all: (stopperFunc=undef) ->

		dbgEnter "Getter.all"

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(hNode = @get())
			if defined(stopperFunc) && stopperFunc(hNode)
				@getStopperNode = hNode
				dbgReturn 'Getter.all'
				return
			assert defined(hNode.uobj), "uobj is not defined"
			dbgYield 'Getter.all', hNode
			yield hNode
			dbgResume 'Getter.all'
		dbgReturn "Getter.all"
		return
