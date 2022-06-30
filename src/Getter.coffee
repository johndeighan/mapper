# Getter.coffee

import {
	assert, undef, pass, croak, OL, rtrim, defined, notdefined,
	escapeStr, isString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock, blockToArray} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'
import {
	parseSource, slurp, isSimpleFileName, isDir, pathTo,
	} from '@jdeighan/coffee-utils/fs'

import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------
#   class Getter
#      - get(), peek(), eof(), skip() for mapped data

export class Getter extends Fetcher

	constructor: (source=undef, collection=undef, hOptions={}) ->

		super source, collection, hOptions

		@hConsts = {}   # support variable replacement

		# --- support peek(), etc.
		#     items are {item, uobj}
		@lCache = []

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
	#    Cache Management
	# ..........................................................

	addToCache: (item, uobj) ->
		# --- uobj is mapped version of item
		#     uobj may be undef

		@lCache.unshift {item, uobj}
		return

	# ..........................................................

	getFromCache: () ->

		assert nonEmpty(@lCache), "empty cache"
		{item, uobj} = @lCache.shift()
		if uobj
			return uobj
		else
			return @mapItem(item)

	# ..........................................................

	fetchFromCache: () ->

		assert nonEmpty(@lCache), "empty cache"
		{item, uobj} = @lCache.shift()
		return h.item

	# ..........................................................
	#        We override fetch(), unfetch()
	# ..........................................................

	fetch: () ->

		if nonEmpty(@lCache)
			return @fetchFromCache()
		return super()

	# ..........................................................

	unfetch: (line) ->

		if isEmpty(@lCache)
			return super(line)
		@addToCache line, undef
		return

	# ..........................................................
	#        Mapped Data
	# ..........................................................

	get: () ->

		debug "enter get()"

		# --- return anything in @lCache
		if nonEmpty(@lCache)
			uobj = @getFromCache()
			debug "return from get() - cached uobj", uobj
			return uobj
		debug "no lookahead"

		debug "source = #{@sourceInfoStr()}"
		item = @fetch()
		debug "fetch() returned", item
		debug "source = #{@sourceInfoStr()}"

		if (item == undef)
			debug "return undef from get() - at EOF"
			return undef

		uobj = @mapItem(item)
		debug "mapItem() returned", uobj

		if (uobj == undef)
			uobj = @get()    # recursive call

		debug "return from get()", uobj
		return uobj

	# ..........................................................

	skip: () ->

		debug 'enter Getter.skip():'
		@get()
		debug 'return from Getter.skip()'
		return

	# ..........................................................

	eof: () ->

		debug "enter Getter.eof()"

		if nonEmpty(@lCache)
			debug "return false from Getter.eof() - cache not empty"
			return false

		value = @fetch()
		if (value == undef)
			debug "return true from Getter.eof()"
			return true
		else
			@unfetch value
			debug "return false from Getter.eof()"
			return false

	# ..........................................................

	peek: () ->

		debug 'enter Getter.peek()'

		# --- Any item in lCache that has uobj == undef has not
		#     been mapped. lCache may contain such items, but if
		#     they map to undef, they should be skipped
		while nonEmpty(@lCache)
			h = @lCache[0]
			if defined(h.uobj)
				debug "return cached item from Getter.peek()", h.uobj
				return h.uobj
			else
				h.uobj = @mapItem(h.item)
				if defined(h.uobj)
					debug "return cached item from Getter.peek()", h.uobj
					return h.uobj
				else
					@lCache.shift()   # and continue loop

		debug "no lookahead"

		value = @fetch()
		if (value == undef)
			debug "return undef from Getter.peek() - at EOF"
			return undef
		debug "fetch() returned", value

		# --- @lCache is currently empty
		uobj = @mapItem(value)
		debug "from mapItem()", uobj

		# --- @lCache might be non-empty now!!!

		# --- if mapItem() returns undef, skip that item
		if (uobj == undef)
			debug "mapItem() returned undef - recursive call"
			uobj = @peek()    # recursive call
			debug "return from Getter.peek()", uobj
			return uobj

		debug "set lookahead", value, uobj
		@addToCache value, uobj

		debug "return from Getter.peek()", uobj
		return uobj

	# ..........................................................
	# return of undef doesn't mean EOF, it means skip this item

	mapItem: (item) ->

		debug "enter mapItem()", item
		debug "source = #{@sourceInfoStr()}"

		[type, hInfo] = @getItemType(item)
		if defined(type)
			debug "item type is #{type}"
			assert isString(type) && nonEmpty(type), "bad type: #{OL(type)}"
			debug "call handleItemType()"
			uobj = @handleItemType(type, item, hInfo)
			debug "from handleItemType()", uobj
		else
			debug "no special type"
			if isString(item) && (item != '__END__')
				newitem = @replaceConsts(item, @hConsts)
				if (newitem != item)
					debug "=> '#{newitem}'"
					item = newitem

			debug "call map()"
			uobj = @map(item)
			debug "from map()", uobj

		if (uobj == undef)
			debug "return undef from mapItem()"
			return undef
		else
			result = @bundle(uobj)
			assert defined(result), "result is undef"
			debug "return from mapItem()", result
			return result

	# ..........................................................

	bundle: (result) ->
		# --- designed to override - NEVER return undef

		return result

	# ..........................................................

	replaceConsts: (line, hVars={}) ->

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

		return line.replace(///
				__
				(env\.)?
				([A-Za-z_][A-Za-z0-9_]*)
				__
				///g, replacerFunc)

	# ..........................................................

	getItemType: (item) ->
		# --- return [<name of item type>, <additional info>]

		return [undef, undef]   # default: no special item types

	# ..........................................................

	handleItemType: (type, item, hInfo) ->

		return undef    # default - ignore any special item types

	# ..........................................................
	# --- designed to override
	#     override may use fetch(), unfetch(), fetchBlock(), etc.
	#     should return undef to ignore line
	#     technically, line does not have to be a string,
	#        but it usually is

	map: (item) ->

		debug "enter Getter.map() - identity mapping", item
		assert defined(item), "item is undef"

		# --- by default, identity mapping
		debug "return from Getter.map()", item
		return item

	# ..........................................................
	# --- override to map back to a string, default returns arg
	#     used in getBlock()

	unmap: (item) ->

		return item

	# ..........................................................
	# --- a generator

	allMapped: () ->

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(item = @get())
			yield item
		return

	# ..........................................................

	getAll: () ->

		debug "enter Getter.getAll()"
		lItems = []
		for item from @allMapped()
			lItems.push item
		debug "return from Getter.getAll()", lItems
		return lItems

	# ..........................................................

	getUntil: (end) ->

		debug "enter Getter.getUntil()"
		lItems = []
		while defined(item = @get()) && (item != end)
			lItems.push item
		debug "return from Getter.getUntil()", lItems
		return lItems

	# ..........................................................

	getBlock: () ->

		debug "enter Getter.getBlock()"
		lStrings = []
		for item from @allMapped()
			debug "MAPPED", item
			item = @unmap(item)
			assert isString(item), "mapped item not a string"
			lStrings.push item
		debug 'lStrings', lStrings
		endStr = @endBlock()
		if defined(endStr)
			debug 'endStr', endStr
			lStrings.push endStr
		block = @finalizeBlock(arrayToBlock(lStrings))
		debug "return from Getter.getBlock()", block
		return block

	# ..........................................................

	endBlock: () ->

		return undef

	# ..........................................................

	finalizeBlock: (block) ->

		return block
