# Fetcher.coffee

import fs from 'fs'

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, OL, rtrim, defined, notdefined,
	escapeStr, isString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {
	splitPrefix, indentLevel, undented,
	} from '@jdeighan/coffee-utils/indent'
import {arrayToBlock, blockToArray} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'
import {
	parseSource, slurp, isSimpleFileName, isDir, pathTo,
	} from '@jdeighan/coffee-utils/fs'

import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------
#   class Fetcher
#      - sets @hSourceInfo
#      - fetch(), unfetch()
#      - removes trailing WS from strings
#      - stops at __END__
#      - all() - generator
#      - fetchAll(), fetchBlock(), fetchUntil()

export class Fetcher

	constructor: (@source=undef, collection=undef, @addLevel=0) ->

		debug "enter Fetcher()", @source, collection, @addLevel

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
	# --- returns hNode with keys:
	#        str
	#        level
	#        source
	#        lineNum

	fetch: () ->

		debug "enter Fetcher.fetch() from #{@hSourceInfo.filename}"

		if defined(@altInput)
			debug "has altInput"
			hNode = @altInput.fetch()

			# --- NOTE: hNode.str will never be #include
			#           because altInput's fetch would handle it

			if defined(hNode)
				debug "return from Fetcher.fetch() - alt", hNode
				return hNode

			# --- alternate input is exhausted
			@altInput = undef
			debug "alt EOF"
		else
			debug "there is no altInput"

		# --- return anything in lLookAhead,
		#     even if @forcedEOF is true
		if (@lLookAhead.length > 0)
			hNode = @lLookAhead.shift()
			assert defined(hNode), "undef in lLookAhead"
			assert ! hNode.str.match(/^\#include\b/),
				"got #{OL(hNode)} from lLookAhead"

			# --- NOTE: hNode.str will never be #include
			#           because anything that came from lLookAhead
			#           was put there by unfetch() which doesn't
			#           allow #include

			@incLineNum 1
			debug "return from Fetcher.fetch() - lookahead", hNode
			return hNode

		debug "no lookahead"

		if @forcedEOF
			debug "return from Fetcher.fetch() - forced EOF", undef
			return undef

		debug "not at forced EOF"

		{value: line, done} = @iterator.next()
		debug "iterator returned", {line, done}
		if (done)
			debug "return from Fetcher.fetch() - iterator DONE", undef
			return undef

		assert isString(line), "line is #{OL(line)}"
		if lMatches = line.match(/^(\s*)__END__$/)
			[_, prefix] = lMatches
			assert (prefix == ''), "__END__ should be at level 0"
			@forceEOF()
			debug "return from Fetcher.fetch() - __END__", undef
			return undef

		@incLineNum 1
		[prefix, str] = splitPrefix(line)

		# --- Ensure that @oneIndent is set, if possible
		#     set level
		if (prefix == '')
			level = 0
		else if defined(@oneIndent)
			level = indentLevel(prefix, @oneIndent)
		else
			if lMatches = prefix.match(/^\t+$/)
				@oneIndent = "\t"
				level = prefix.length
			else
				@oneIndent = prefix
				level = 1

		assert defined(@oneIndent) || (prefix == ''),
				"Bad prefix #{OL(prefix)}"

		# --- check for #include
		if lMatches = str.match(///^
				\#
				include \b
				\s*
				(.*)
				$///)
			[_, fname] = lMatches
			debug "#include #{fname}"
			assert nonEmpty(fname), "missing file name in #include"
			@createAltInput fname, level
			hNode = @fetch()    # recursive call
			debug "return from Fetcher.fetch()", hNode
			return hNode

		hNode = new Node(str, level + @addLevel, @sourceInfoStr(), @lineNum)

		debug "return from Fetcher.fetch()", hNode
		return hNode

	# ..........................................................

	createAltInput: (fname, level) ->

		debug "enter createAltInput()", fname, level

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

		@altInput = new Fetcher(fullpath, undef, level)
		debug "return from createAltInput()"
		return

	# ..........................................................

	unfetch: (hNode) ->

		debug "enter Fetcher.unfetch()", hNode
		assert (hNode instanceof Node), "hNode is #{OL(hNode)}"

		if defined(@altInput)
			debug "has alt input"
			@altInput.unfetch hNode
			@incLineNum -1
			debug "return from Fetcher.unfetch() - alt"
			return

		assert defined(hNode), "hNode must be defined"
		lMatches = hNode.str.match(///^
				\#include
				\b
				///)
		assert isEmpty(lMatches), "unfetch() of a #include"

		@lLookAhead.unshift hNode
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
	# --- GENERATOR

	all: () ->

		debug "enter Fetcher.all()"
		while defined(hNode = @fetch())
			debug "GOT", hNode
			yield hNode
		debug "return from Fetcher.all()"
		return

	# ..........................................................
	# --- GENERATOR

	allUntil: (func, hOptions=undef) ->
		# --- stop when func(hNode) returns true

		debug "enter Fetcher.allUntil()"

		assert isFunction(func), "Arg 1 not a function"
		if defined(hOptions)
			discardEndLine = hOptions.discardEndLine
		else
			discardEndLine = true

		while defined(hNode = @fetch()) && ! func(hNode)
			debug "GOT", hNode
			yield hNode

		if defined(hNode) && ! discardEndLine
			@unfetch hNode

		debug "return from Fetcher.allUntil()"
		return

	# ..........................................................
	# --- fetch a list of Nodes

	fetchAll: () ->

		debug "enter Fetcher.fetchAll()"
		lNodes = Array.from(@all())
		debug "return from Fetcher.fetchAll()", lNodes
		return lNodes

	# ..........................................................

	fetchUntil: (func, hOptions=undef) ->

		debug "enter Fetcher.fetchUntil()", func, hOptions
		assert isFunction(func), "not a function: #{OL(func)}"

		lNodes = []
		for hNode from @allUntil(func, hOptions)
			lNodes.push hNode

		debug "return from Fetcher.fetchUntil()", lNodes
		return lNodes

	# ..........................................................
	# --- fetch a block

	fetchBlock: () ->

		debug "enter Fetcher.fetchBlock()"
		lNodes = Array.from(@all())
		result = @toBlock(lNodes)
		debug "return from Fetcher.fetchBlock()", result
		return result

	# ..........................................................

	fetchBlockUntil: (func, hOptions=undef) ->

		debug "enter Fetcher.fetchBlockUntil()"
		lNodes = @fetchUntil(func, hOptions)
		result = @toBlock(lNodes)
		debug "return from Fetcher.fetchBlockUntil()", result
		return result

	# ..........................................................

	toBlock: (lNodes) ->

		lStrings = []
		for hNode in lNodes
			lStrings.push hNode.getLine(@oneIndent)
		lStrings = undented(lStrings)
		return arrayToBlock(lStrings)

