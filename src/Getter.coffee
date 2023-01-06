# Getter.coffee

import {
	undef, pass, OL, rtrim, defined, notdefined,
	escapeStr, isString, isNonEmptyString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty, toBlock, toArray,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	dbgYield, dbgResume,
	} from '@jdeighan/base-utils/debug'

import {Node} from '@jdeighan/mapper/node'
import {FetcherInc} from '@jdeighan/mapper/fetcherinc'

# ---------------------------------------------------------------------------
# 1. implement setConst() and getConst()
# 2. override get() - only return nodes with defined uobj
# 3. override procNode():
#       - replace constants, including env vars
#       - set type field
#       - set field uobj by calling mapNode()

export class Getter extends FetcherInc

	constructor: (hInput, options={}) ->

		super hInput, options
		@hConsts = {}   # support constant replacement

	# ..........................................................

	setConst: (name, value) ->

		assert notdefined(@hConsts[name]), "const #{name} already set"
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

		dbgEnter "Getter.get"

		# --- NOTE: @allNodes() calls procNode() before returning hNode
		#           and we override that below

		for hNode from @allNodes()
			dbg 'fetched hNode', hNode
			if defined(hNode.uobj)
				dbgReturn 'Getter.get', hNode
				return hNode

		dbg "EOF"
		dbgReturn "Getter.get", undef
		return undef

	# ..........................................................

	procNode: (hNode) ->
		# --- overrides Fetcher.procNode()
		#     causing @fetch() to return a node
		#        with key 'uobj' set (possibly to undef)
		# --- Return value:
		#        falsy - discard this node
		#        truthy - keep this node

		dbgEnter 'Getter.procNode', hNode
		super hNode   # currently just asserts that hNode is defined

		if hNode.hasOwnProperty('uobj')
			# --- If it has already been mapped, nothing to do
			#     This can happen if the node has been peeked and mapped
			dbg "node is already mapped to #{OL(hNode.uobj)}"
		else
			{str} = hNode
			assert defined(str), "str is undef"
			assert isString(str), "str is not a string"
			assert notdefined(str.match(/^\s/)), "str has leading whitespace"
			assert (str != '__END__'), "__END__ encountered"

			# --- Replace any constants
			newstr = @replaceConsts(str, hNode)
			if (newstr != str)
				dbg "#{OL(str)} => #{OL(newstr)}"
				hNode.str = newstr

			type = @getItemType(hNode)
			if defined(type)
				assert isNonEmptyString(type), "bad type: #{OL(type)}"
				hNode.type = type
			else
				dbg "no special type"

			hNode.uobj = @mapNode(hNode)
			dbg "mapped to uobj", hNode.uobj

		result = defined(hNode.uobj)
		dbgReturn 'Getter.procNode', result
		return result

	# ..........................................................
	# --- designed to override

	getItemType: (hNode) ->
		# --- returns name of item type

		return undef   # default: no special item types

	# ..........................................................
	# --- designed to override

	mapNode: (hNode) ->
		# --- default:
		#        specials return undef
		#        non-specials return hNode.str

		if hNode.type
			return undef
		else
			return hNode.str

	# ..........................................................

	replaceConsts: (str, hNode) ->

		replacerFunc = (match, prefix, name) =>
			# --- match is the matched substring (see regexp below)
			#     prefix and name are captured groups
			#     If prefix is set, it's always 'env.'
			#     If name is set, it does NOT include the prefix

			if prefix
				return process.env[name]
			else if (name == 'LINE')
				{source} = hNode
				if notdefined(source)
					return "<NOT DEFINED: source>"
				lMatches = source.match(/\d+$/)
				if notdefined(lMatches)
					return "<BAD SOURCE #{OL(source)}>"
				return lMatches[0]
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
