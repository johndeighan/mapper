# Getter.coffee

import {
	assert, undef, pass, croak, OL, rtrim, defined, notdefined,
	escapeStr, isString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock, blockToArray} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------
#   class Getter
#      - get(), peek(), eof(), skip() for mapped data

export class Getter extends Fetcher

	constructor: (source=undef, collection=undef, hOptions={}) ->

		super source, collection, hOptions

		@hConsts = {}   # support variable replacement

		# --- support peek(), etc.
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

	fetchFromCache: () ->

		assert nonEmpty(@lCache), "empty cache"
		hLine = @lCache.shift()
		assert defined(hLine), "undef item found in lCache"
		return hLine

	# ..........................................................

	getFromCache: () ->

		while nonEmpty(@lCache)
			hLine = @fetchFromCache()
			if defined(hLine.uobj)
				return hLine
			else
				uobj = hLine.uobj = @mapItem(hLine)
				if defined(uobj)
					return hLine

		return undef

	# ..........................................................
	#        We override fetch(), unfetch()
	# ..........................................................

	fetch: () ->

		if nonEmpty(@lCache)
			return @fetchFromCache()
		return super()

	# ..........................................................

	unfetch: (hLine) ->

# --- I think these are wrong, so I'm commenting them out for now
#		if isEmpty(@lCache)
#			return super(hLine)
		assert defined(hLine), "attempt to put undef in lCache"
		@lCache.unshift hLine
		return

	# ..........................................................
	#        Mapped Data
	# --- add keys:
	#        type   - if a special type
	#        uobj
	# ..........................................................

	get: () ->

		debug "enter Getter.get()"

		# --- return anything in @lCache
		#     NOTE: getFromCache() may return undef if all items
		#           in cache have not been mapped, and all of them
		#           map to undef
		debug 'lCache', @lCache
		if defined(hLine = @getFromCache())
			# --- NOTE: return value from getFromCache()
			#           should always have a uobj key
			assert defined(hLine.uobj), "getFromCache() but no uobj"
			debug "return from Getter.get() - cached hLine", hLine
			return hLine

		debug "no cached hLine"

		hLine = @fetch()
		debug "fetch() returned", hLine

		if (hLine == undef)
			debug "return from Getter.get() - at EOF", undef
			return undef

		uobj = hLine.uobj = @mapItem(hLine)

		if (uobj == undef)
			hLine = @get()    # recursive call

		debug "return from Getter.get()", hLine
		return hLine

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
			debug "return from Getter.eof() - cache not empty", false
			return false

		hLine = @fetch()
		if (hLine == undef)
			debug "return from Getter.eof()", true
			return true
		else
			@unfetch hLine
			debug "return from Getter.eof()", false
			return false

	# ..........................................................

	peek: () ->

		debug 'enter Getter.peek()'

		# --- Any item in lCache that has uobj == undef has not
		#     been mapped. lCache may contain such items, but if
		#     they map to undef, they should be skipped
		while nonEmpty(@lCache)
			hLine = @lCache[0]
			assert defined(hLine), "hLine (from cache) is undef"
			if defined(hLine.uobj)
				debug "return cached item from Getter.peek()", hLine
				return hLine
			else
				uobj = hLine.uobj = @mapItem(hLine)
				if defined(uobj)
					debug "return cached item from Getter.peek()", hLine
					return hLine
				else
					@lCache.shift()   # and continue loop

		debug "no lookahead"

		hLine = @fetch()
		if (hLine == undef)
			debug "return undef from Getter.peek() - at EOF"
			return undef
		debug "fetch() returned", hLine

		# --- @lCache is currently empty
		uobj = hLine.uobj = @mapItem(hLine)

		# --- @lCache might be non-empty now!!!

		# --- if mapItem() returns undef, skip that item
		if (uobj == undef)
			debug "mapItem() returned undef - recursive call"
			hLine = @peek()    # recursive call
			debug "return from Getter.peek()", hLine
			return hLine

		debug "add to cache", hLine
		@lCache.unshift hLine

		debug "return from Getter.peek()", hLine
		return hLine

	# ..........................................................
	# --- return of undef doesn't mean EOF, it means skip this item
	#     sets key 'uobj' to a defined value if not returning undef
	#     sets key 'type' if a special type

	mapItem: (hLine) ->

		debug "enter Getter.mapItem()", hLine
		assert defined(hLine), "hLine is undef"

		if defined(type = @getItemType(hLine))
			debug "item type is #{type}"
			assert isString(type) && nonEmpty(type), "bad type: #{OL(type)}"
			hLine.type = type
			debug "call handleItemType()"
			uobj = @handleItemType(type, hLine)
			debug "from handleItemType()", uobj
		else
			debug "no special type"
			{line, str, prefix} = hLine
			if isString(line)
				assert isString(str), "missing 'str' key in #{OL(line)}"
				assert nonEmpty(str), "str is empty"
				assert (line != '__END__'), "__END__ encountered"
				newstr = @replaceConsts(str, @hConsts)
				if (newstr != str)
					newline = "#{prefix}#{newstr}"
					debug "=> '#{newline}'"

					hLine.str = newstr
					hLine.line = newline

			debug "call map()"
			uobj = @map(hLine)
			debug "from map()", uobj

		if (uobj == undef)
			debug "return from Getter.mapItem()", undef
			return undef

		debug "return from Getter.mapItem()", uobj
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

	getItemType: (hLine) ->
		# --- returns name of item type

		return undef   # default: no special item types

	# ..........................................................

	handleItemType: (type, hLine) ->

		return undef    # default - ignore any special item types

	# ..........................................................
	# --- designed to override
	#     override may use fetch(), unfetch(), fetchBlock(), etc.
	#     should return a uobj (undef to ignore line)
	#     technically, hLine.line does not have to be a string,
	#        but it usually is

	map: (hLine) ->
		# --- returns a uobj or undef
		#     uobj will be passed to visit() and endVisit() in TreeWalker

		debug "enter Getter.map()", hLine
		assert defined(hLine), "hLine is undef"

		# --- by default, just returns line key
		debug "return from Getter.map()", hLine.line
		return hLine.line

	# ..........................................................
	# --- a generator

	allMapped: () ->

		# --- NOTE: @get will skip items that are mapped to undef
		#           and only returns undef when the input is exhausted
		while defined(hLine = @get())
			yield hLine
		return

	# ..........................................................

	getAll: () ->

		debug "enter Getter.getAll()"
		lLines = Array.from(@allMapped())
		debug "return from Getter.getAll()", lLines
		return lLines

	# ..........................................................

	getUntil: (endLine) ->

		debug "enter Getter.getUntil()"
		lLines = []
		while defined(hLine = @get()) && (hLine.line != endLine)
			lLines.push hLine.line
		debug "return from Getter.getUntil()", lLines
		return lLines

	# ..........................................................

	getBlock: (hOptions={}) ->
		# --- Valid options: logLines

		debug "enter Getter.getBlock()"
		lStrings = []
		i = 0
		for hLine from @allMapped()
			if hOptions.logLines
				LOG "hLine[#{i}]", hLine
			else
				debug "hLine", hLine
			i += 1

			uobj = hLine.uobj
			assert isString(uobj), "uobj not a string"
			lStrings.push uobj
		debug 'lStrings', lStrings
		endStr = @endBlock()
		if defined(endStr = @endBlock())
			debug 'endStr', endStr
			lStrings.push endStr

		if hOptions.logLines
			LOG 'lStrings', lStrings

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
