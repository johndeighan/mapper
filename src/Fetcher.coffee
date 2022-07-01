# Fetcher.coffee

import fs from 'fs'

import {
	assert, undef, pass, croak, OL, rtrim, defined,
	escapeStr, isString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock, blockToArray} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'
import {
	parseSource, slurp, isSimpleFileName, isDir, pathTo,
	} from '@jdeighan/coffee-utils/fs'

# ---------------------------------------------------------------------------
#   class Fetcher
#      - sets @hSourceInfo
#      - fetch(), unfetch()
#      - removes trailing WS from strings
#      - stops at __END__
#      - valid options:
#           prefix - prepend this prefix when fetching
#      - all() - generator
#      - fetchAll(), fetchBlock(), fetchUntil()

export class Fetcher

	constructor: (source=undef, collection=undef, hOptions={}) ->

		debug "enter Fetcher(#{OL(source)})", collection

		if source
			@hSourceInfo = parseSource(source)
			debug 'hSourceInfo', @hSourceInfo
			assert @hSourceInfo.filename,
					"parseSource returned no filename"
		else
			@hSourceInfo = {
				filename: '<unknown>'
				}

		# --- Add current line number to hSourceInfo
		@hSourceInfo.lineNum = 0

		if hOptions.prefix?
			@hSourceInfo.prefix = hOptions.prefix

		if (collection == undef)
			if @hSourceInfo.fullpath
				content = slurp(@hSourceInfo.fullpath)
				debug 'content', content
				collection = blockToArray(content)
			else
				croak "no source or fullpath"
		else if isString(collection)
			collection = blockToArray(collection)
			debug "collection becomes", collection

		# --- collection must be iterable
		assert isIterable(collection), "collection not iterable"
		@iterator = collection[Symbol.iterator]()
		@lLookAhead = []   # --- support unfetch()
		@forcedEOF = false

		if defined(hOptions.prefix)
			@prefix = hOptions.prefix
		else
			@prefix = ''
		debug 'prefix', @prefix

		@init()
		debug "return from Fetcher()"

	# ..........................................................

	pathTo: (fname) ->
		# --- fname must be a simple file name
		# --- returns a relative path
		#     searches from @hSourceInfo.dir || process.cwd()
		#     searches downward

		assert isSimpleFileName(fname), "fname must not be a path"
		return pathTo(fname, @hSourceInfo.dir, {relative: true})

	# ..........................................................

	init: () ->

		return

	# ..........................................................

	sourceInfoStr: () ->

		lParts = []
		h = @hSourceInfo
		lParts.push @sourceStr(h)
		while defined(h.altInput)
			h = h.altInput.hSourceInfo
			lParts.push @sourceStr(h)
		return lParts.join(' ')

	# ..........................................................

	sourceStr: (h) ->

		assert isHash(h, ['filename','lineNum']), "h is #{OL(h)}"
		return "#{h.filename}/#{h.lineNum}"

	# ..........................................................

	fetch: () ->

		debug "enter Fetcher.fetch() from #{@hSourceInfo.filename}"

		if defined(@hSourceInfo.altInput)
			debug "has altInput"
			value = @hSourceInfo.altInput.fetch()

			# --- NOTE: value will never be #include
			#           because altInput's fetch would handle it

			if defined(value)
				debug "got alt value", value
				debug "return from Fetcher.fetch() - alt", value
				return value

			# --- alternate input is exhausted
			@hSourceInfo.altInput = undef
			debug "alt EOF"
		else
			debug "there is no altInput"

		# --- return anything in lLookAhead,
		#     even if @forcedEOF is true
		if (@lLookAhead.length > 0)
			value = @lLookAhead.shift()

			# --- NOTE: value will never be #include
			#           because anything that came from lLookAhead
			#           was put there by unfetch() which doesn't
			#           allow #include

			assert defined(value), "undef in lLookAhead"
			@incLineNum 1
			debug "return from Fetcher.fetch() - lookahead", value
			return value

		debug "no lookahead"

		if @forcedEOF
			debug "return undef from Fetcher.fetch() - forced EOF"
			return undef

		debug "not at EOF"

		{value, done} = @iterator.next()
		debug "iterator returned", {value, done}
		if (done)
			debug "return undef from Fetcher.fetch() - iterator DONE"
			return undef

		if (value == '__END__')
			@forceEOF()
			debug "return undef from Fetcher.fetch() - __END__"
			return undef

		@incLineNum 1

		if isString(value)

			value = rtrim(value)  # remove trailing whitespace

			# --- check for #include
			if lMatches = value.match(///
					(\s*)      # prefix
					\#
					include \b
					\s*
					(.*)
					$///)
				[_, prefix, fname] = lMatches
				debug "#include #{fname} with prefix '#{escapeStr(prefix)}'"
				assert nonEmpty(fname), "missing file name in #include"
				@createAltInput fname, prefix
				value = @fetch()    # recursive call
				debug "return from Fetcher.fetch()", value
				return value

		if @prefix
			assert isString(value), "prefix with non-string value"
			value = @prefix + value

		debug "return from Fetcher.fetch()", value
		return value

	# ..........................................................

	createAltInput: (fname, prefix='') ->

		debug "enter createAltInput('#{fname}', '#{escapeStr(prefix)}')"

		# --- Make sure we have a simple file name
		assert isString(fname), "not a string: #{OL(fname)}"
		assert isSimpleFileName(fname),
				"not a simple file name: #{OL(fname)}"

		# --- Decide which directory to search for file
		dir = @hSourceInfo.dir
		if dir
			assert isDir(dir), "not a directory: #{OL(dir)}"
		else
			dir = process.cwd()  # --- Use current directory

		fullpath = pathTo(fname, dir)
		debug "fullpath", fullpath
		if (fullpath == undef)
			croak "Can't find include file #{fname} in dir #{dir}"
		assert fs.existsSync(fullpath), "#{fullpath} does not exist"

		@hSourceInfo.altInput = new Fetcher(fullpath, undef, {prefix})

		debug "return from createAltInput()"
		return

	# ..........................................................

	unfetch: (value) ->

		debug "enter Fetcher.unfetch()", value
		assert defined(value), "value must be defined"
		if isString(value)
			lMatches = value.match(///^
					\s*
					\#include
					///)
			assert isEmpty(lMatches), "unfetch() of a #include"

		if defined(@hSourceInfo.altInput)
			debug "has alt input"
			@hSourceInfo.altInput.unfetch value
			@incLineNum -1
			debug "return from Fetcher.unfetch() - alt"
			return

		@lLookAhead.unshift value
		@incLineNum -1
		debug "return from Fetcher.unfetch()"
		return

	# ..........................................................
	# --- override to keep variable LINE updated

	incLineNum: (inc=1) ->

		@hSourceInfo.lineNum += inc
		return

	# ..........................................................

	forceEOF: () ->

		debug "enter forceEOF()"
		@forcedEOF = true
		debug "return from forceEOF()"
		return

	# ..........................................................
	# --- a generator

	all: () ->

		debug "enter Fetcher.all()"
		while defined(item = @fetch())
			debug "GOT", item
			yield item
		debug "GOT", item
		debug "return from Fetcher.all()"
		return

	# ..........................................................

	fetchAll: () ->

		debug "enter Fetcher.fetchAll()"
		lItems = []
		for item from @all()
			lItems.push item
		debug "return from Fetcher.fetchAll()", lItems
		return lItems

	# ..........................................................

	fetchUntil: (end) ->

		debug "enter Fetcher.fetchUntil()"
		lItems = []
		while defined(item = @fetch()) && (item != end)
			lItems.push item
		debug "return from Fetcher.fetchUntil()", lItems
		return lItems

	# ..........................................................

	fetchBlock: () ->

		debug "enter Fetcher.fetchBlock()"
		lStrings = []
		for str from @all()
			assert isString(str), "fetchBlock(): non-string #{OL(str)}"
			lStrings.push(str)
		debug 'lStrings', lStrings
		block = arrayToBlock(lStrings)
		debug "return from Fetcher.fetchBlock()", block
		return block
