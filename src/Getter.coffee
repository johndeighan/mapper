# Getter.coffee

import {
	assert, undef, pass, croak, OL, rtrim, defined, notdefined,
	escapeStr, isString, isHash, isArray, replaceVars,
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

		@hVars = {}   # support variable replacement

		# --- support peek(), etc.
		#     items are {line, mapped, isMapped}
		@lCache = []   # --- support peek()

	# ..........................................................

	setVar: (name, value) ->

		@hVars[name] = value
		return

	# ..........................................................
	#    Cache Management
	# ..........................................................

	addToCache: (line, mapped=undef, isMapped=true) ->

		@lCache.unshift {
			line
			mapped
			isMapped
			}
		return

	# ..........................................................

	getFromCache: () ->

		assert nonEmpty(@lCache), "getFromCache() called on empty cache"
		h = @lCache.shift()
		if h.isMapped
			return h.mapped
		else
			return @mapItem(h.line)

	# ..........................................................

	fetchFromCache: () ->

		assert nonEmpty(@lCache), "fetchFromCache() called on empty cache"
		h = @lCache.shift()
		return h.unmapped

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
		@addToCache line, undef, false
		return

	# ..........................................................
	#        Mapped Data
	# ..........................................................

	get: () ->

		debug "enter Getter.get()"

		# --- return anything in @lCache
		if nonEmpty(@lCache)
			value = @getFromCache()
			debug "return from Getter.get() - mapped lookahead", value
			return value
		debug "no lookahead"

		item = @fetch()
		debug "fetch() returned", item

		if (item == undef)
			debug "return undef from Getter.get() - at EOF"
			return undef

		result = @mapItem(item)
		debug "mapItem() returned", result

		if (result == undef)
			result = @get()    # recursive call

		debug "return from Getter.get()", result
		return result

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

		if nonEmpty(@lCache)
			h = @lCache[0]
			if ! h.isMapped
				h.mapped = @mapItem(h.line)
				h.isMapped = true

			debug "return lookahead token from Getter.peek()", h.mapped
			return h.mapped
		debug "no lookahead"

		value = @fetch()
		if (value == undef)
			debug "return undef from Getter.peek() - at EOF"
			return undef
		debug "fetch() returned", value

		# --- @lCache is currently empty
		result = @mapItem(value)
		debug "from mapItem()", result

		# --- @lCache might be non-empty now!!!

		# --- if mapItem() returns undef, skip that item
		if (result == undef)
			debug "mapItem() returned undef - recursive call"
			result = @peek()    # recursive call
			debug "return from Getter.peek()", result
			return result

		debug "set lookahead", result
		@addToCache value, result, true

		debug "return from Getter.peek()", result
		return result

	# ..........................................................
	# return of undef doesn't mean EOF, it means skip this item

	mapItem: (item) ->

		debug "enter Getter.mapItem()", item

		result = @getItemType(item)
		if defined(result)
			[type, hInfo] = result
			debug "item type is #{type}"
			assert isString(type) && nonEmpty(type), "bad type: #{OL(type)}"
			debug "call handleItemType()"
			result = @handleItemType(type, item, hInfo)
			debug "from handleItemType()", result
		else
			if isString(item) && (item != '__END__')
				debug "replace vars"
				newitem = replaceVars(item, @hVars)
				if (newitem != item)
					debug "=> '#{newitem}'"
				item = newitem

			debug "call map()"
			result = @map(item)
			debug "from map()", result

		debug "return from Getter.mapItem()", result
		return result

	# ..........................................................

	getItemType: (item) ->
		# --- return [<name of item type>, <additional info>]

		return undef     # default: not special item types

	# ..........................................................

	handleItemType: (type, item, hInfo) ->

		return undef    # default - ignore any special item types

	# ..........................................................
	# --- designed to override
	#     override may use fetch(), unfetch(), fetchBlock(), etc.
	#     should return undef to ignore line
	#     technically, line does not have to be a string,
	#        but it usually is

	map: (line) ->

		debug "enter Getter.map() - identity mapping", line
		assert defined(line), "line is undef"

		# --- by default, identity mapping
		debug "return from Getter.map()", line
		return line

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
		block = arrayToBlock(lStrings)
		debug "return from Getter.getBlock()", block
		return block

	# ..........................................................

	endBlock: () ->

		return undef
