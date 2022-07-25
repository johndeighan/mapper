# Fetcher.coffee

import fs from 'fs'

import {
	assert, undef, pass, croak, OL, rtrim, defined,
	escapeStr, isString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {splitPrefix, indentLevel} from '@jdeighan/coffee-utils/indent'
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

	constructor: (@source=undef, collection=undef, hOptions={}) ->

		debug "enter Fetcher(#{OL(@source)})", collection

		if @source
			@hSourceInfo = parseSource(@source)
			debug 'hSourceInfo', @hSourceInfo
			assert @hSourceInfo.filename,
					"parseSource returned no filename"
		else
			@hSourceInfo = {
				filename: '<unknown>'
				}

		@altInput = undef
		@lineNum = 0
		@oneIndent = undef   # set from 1st line with indentation

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
		lParts.push @sourceStr()
		if defined(@altInput)
			lParts.push @altInput.sourceStr()
		return lParts.join(' ')

	# ..........................................................

	sourceStr: () ->

		return "#{@hSourceInfo.filename}/#{@lineNum}"

	# ..........................................................
	# --- returns hLine with keys:
	#        line
	#        source
	#        lineNum
	# --- if line is a string:
	#        prefix
	#        str
	#        srcLevel
	#        level

	fetch: () ->

		debug "enter Fetcher.fetch() from #{@hSourceInfo.filename}"

		if defined(@altInput)
			debug "has altInput"
			hLine = @altInput.fetch()

			# --- NOTE: hLine.line will never be #include
			#           because altInput's fetch would handle it

			if defined(hLine)
				debug "return from Fetcher.fetch() - alt", hLine
				return hLine

			# --- alternate input is exhausted
			@altInput = undef
			debug "alt EOF"
		else
			debug "there is no altInput"

		# --- return anything in lLookAhead,
		#     even if @forcedEOF is true
		if (@lLookAhead.length > 0)
			hLine = @lLookAhead.shift()

			# --- NOTE: hLine.line will never be #include
			#           because anything that came from lLookAhead
			#           was put there by unfetch() which doesn't
			#           allow #include

			assert defined(hLine), "undef in lLookAhead"
			@incLineNum 1
			debug "return from Fetcher.fetch() - lookahead", hLine
			return hLine

		debug "no lookahead"

		if @forcedEOF
			debug "return from Fetcher.fetch() - forced EOF", undef
			return undef

		debug "not at forced EOF"

		{value, done} = @iterator.next()
		line = value
		debug "iterator returned", {line, done}
		if (done)
			debug "return from Fetcher.fetch() - iterator DONE", undef
			return undef

		if (line == '__END__')
			@forceEOF()
			debug "return from Fetcher.fetch() - __END__", undef
			return undef

		@incLineNum 1

		# --- this object is returned at the end
		hLine = {
			line
			lineNum: @lineNum
			source: @sourceInfoStr()
			}

		if isString(line)

			line = rtrim(line)  # remove trailing whitespace

			# --- check for #include
			if lMatches = line.match(///
					(\s*)      # prefix
					\#
					include \b
					\s*
					(.*)
					$///)
				[_, prefix, fname] = lMatches
				debug "#include #{fname} with prefix '#{OL(prefix)}'"
				assert nonEmpty(fname), "missing file name in #include"
				@createAltInput fname, prefix
				hLine = @fetch()    # recursive call
				debug "return from Fetcher.fetch()", hLine
				return hLine

			# --- Check if we're adding a prefix to each line
			if (@prefix.length > 0)
				line = @prefix + line

			[prefix, str] = splitPrefix(line)
			if defined(@oneIndent)
				level = indentLevel(line, @oneIndent)
			else if (prefix == '')
				level = 0
			else if lMatches = prefix.match(/^\t+$/)
				@oneIndent = "\t"
				level = lMatches[0].length
			else
				level = 1
				@oneIndent = prefix

			hLine.line = line      # trimmed version
			hLine.prefix = prefix
			hLine.str = str
			hLine.srcLevel = level
			hLine.level = level

		debug "return from Fetcher.fetch()", hLine
		return hLine

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

		@altInput = new Fetcher(fullpath, undef, {prefix})

		debug "return from createAltInput()"
		return

	# ..........................................................

	unfetch: (hLine) ->

		debug "enter Fetcher.unfetch()", hLine
		assert defined(hLine), "hLine must be defined"
		{line} = hLine
		if isString(line)
			lMatches = line.match(///^
					\s*
					\#include
					\b
					///)
			assert isEmpty(lMatches), "unfetch() of a #include"

		if defined(@altInput)
			debug "has alt input"
			@altInput.unfetch hLine
			@incLineNum -1
			debug "return from Fetcher.unfetch() - alt"
			return

		@lLookAhead.unshift hLine
		@incLineNum -1
		debug "return from Fetcher.unfetch()"
		return

	# ..........................................................
	# --- override to keep variable LINE updated

	incLineNum: (inc=1) ->

		@lineNum += inc
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
		while defined(hLine = @fetch())
			debug "GOT", hLine
			yield hLine
		debug "GOT", hLine
		debug "return from Fetcher.all()"
		return

	# ..........................................................

	fetchAll: () ->

		debug "enter Fetcher.fetchAll()"
		lLines = []
		for hLine from @all()
			lLines.push hLine
		debug "return from Fetcher.fetchAll()", lLines
		return lLines

	# ..........................................................

	fetchUntil: (end) ->

		debug "enter Fetcher.fetchUntil()"
		lLines = []
		while defined(hLine = @fetch()) && (hLine.line != end)
			lLines.push hLine
		debug "return from Fetcher.fetchUntil()", lLines
		return lLines

	# ..........................................................

	fetchBlock: () ->

		debug "enter Fetcher.fetchBlock()"
		lStrings = []
		for hLine from @all()
			assert isString(hLine.line),
					"fetchBlock(): non-string #{OL(hLine.line)}"
			lStrings.push(hLine.line)
		debug 'lStrings', lStrings
		block = arrayToBlock(lStrings)
		debug "return from Fetcher.fetchBlock()", block
		return block
