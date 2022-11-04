# Fetcher.coffee

import fs from 'fs'

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn, dbgYield, dbgResume,
	} from '@jdeighan/base-utils/debug'
import {
	undef, pass, OL, rtrim, defined, notdefined,
	escapeStr, isString, isHash, isArray,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {
	splitPrefix, indentLevel, undented,
	} from '@jdeighan/coffee-utils/indent'
import {arrayToBlock, blockToArray} from '@jdeighan/coffee-utils/block'
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

		dbgEnter "Fetcher", @source, collection, @addLevel

		if @source
			@hSourceInfo = parseSource(@source)
			dbg 'hSourceInfo', @hSourceInfo
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
				dbg 'content', content
				collection = blockToArray(content)
			else
				croak "no source or fullpath"
		else if isString(collection)
			collection = blockToArray(collection)
			dbg "collection becomes", collection

		# --- collection must be iterable
		assert isIterable(collection), "collection not iterable"
		@iterator = collection[Symbol.iterator]()
		@lLookAhead = []   # --- support unfetch()
		@forcedEOF = false

		@init()
		dbgReturn "Fetcher"

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
	#        source
	#        lineNum
	#        str
	#        srcLevel - level in source code
	#        level    - includes added levels when #include'ing

	fetch: () ->

		dbgEnter "Fetcher.fetch"

		if defined(@altInput)
			dbg "has altInput"
			hNode = @altInput.fetch()

			# --- NOTE: hNode.str will never be #include
			#           because altInput's fetch would handle it

			if defined(hNode)
				# --- NOTE: altInput was created knowing how many levels
				#           to add due to indentation in #include statement
				dbg "from alt"
				dbgReturn "Fetcher.fetch", hNode
				return hNode

			# --- alternate input is exhausted
			@altInput = undef
			dbg "alt EOF"
		else
			dbg "there is no altInput"

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
			dbg "from lookahead"
			dbgReturn "Fetcher.fetch", hNode
			return hNode

		dbg "no lookahead"

		if @forcedEOF
			dbg "forced EOF"
			dbgReturn "Fetcher.fetch", undef
			return undef

		dbg "not at forced EOF"

		{value: line, done} = @iterator.next()
		dbg "iterator returned", {line, done}
		if (done)
			dbg "iterator DONE"
			dbgReturn "Fetcher.fetch", undef
			return undef

		assert isString(line), "line is #{OL(line)}"
		if lMatches = line.match(/^(\s*)__END__$/)
			[_, prefix] = lMatches
			assert (prefix == ''), "__END__ should be at level 0"
			@forceEOF()
			dbg "__END__"
			dbgReturn "Fetcher.fetch", undef
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
			dbg "#include #{fname}"
			assert nonEmpty(fname), "missing file name in #include"
			@createAltInput fname, level
			hNode = @fetch()    # recursive call
			dbgReturn "Fetcher.fetch", hNode
			return hNode

		dbg "oneIndent", @oneIndent
		hNode = new Node(str, level + @addLevel, @sourceInfoStr(), @lineNum)

		dbgReturn "Fetcher.fetch", hNode
		return hNode

	# ..........................................................

	createAltInput: (fname, level) ->

		dbgEnter "createAltInput", fname, level

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
		dbg "fullpath", fullpath
		if (fullpath == undef)
			croak "Can't find include file #{fname} in dir #{dir}"
		assert fs.existsSync(fullpath), "#{fullpath} does not exist"

		@altInput = new Fetcher(fullpath, undef, level)
		dbgReturn "createAltInput"
		return

	# ..........................................................

	unfetch: (hNode) ->

		dbgEnter "Fetcher.unfetch", hNode
		assert (hNode instanceof Node), "hNode is #{OL(hNode)}"

		if defined(@altInput)
			dbg "has alt input"
			@altInput.unfetch hNode
			dbg "alt input"
			dbgReturn "Fetcher.unfetch"
			return

		assert defined(hNode), "hNode must be defined"
		lMatches = hNode.str.match(///^
				\#include
				\b
				///)
		assert isEmpty(lMatches), "unfetch() of a #include"

		@lLookAhead.unshift hNode
		@incLineNum -1
		dbgReturn "Fetcher.unfetch"
		return

	# ..........................................................
	# --- override to keep variable LINE updated

	incLineNum: (inc=1) ->

		@lineNum += inc
		return

	# ..........................................................

	forceEOF: () ->

		dbgEnter "forceEOF"
		@forcedEOF = true
		dbgReturn "forceEOF"
		return

	# ..........................................................
	# --- GENERATOR

	all: () ->

		dbgEnter "Fetcher.all"
		while defined(hNode = @fetch())
			dbgYield "Fetcher.all", hNode
			yield hNode
			dbgResume "Fetcher.all"
		dbgReturn "Fetcher.all"
		return

	# ..........................................................
	# --- GENERATOR

	allUntil: (func, endLineOption) ->
		# --- stop when func(hNode) returns true

		dbgEnter "Fetcher.allUntil", func, endLineOption
		assert (endLineOption=='keepEndLine') \
			|| (endLineOption=='discardEndLine'),
			"bad end line option: #{OL(endLineOption)}"

		assert isFunction(func), "Arg 1 not a function"

		while defined(hNode = @fetch()) && ! func(hNode)
			dbgYield "Fetcher.allUntil", hNode
			yield hNode
			dbgResume "Fetcher.allUntil"

		if defined(hNode) && (endLineOption == 'keepEndLine')
			@unfetch hNode

		dbgReturn "Fetcher.allUntil"
		return

	# ..........................................................
	# --- fetch a list of Nodes

	fetchAll: () ->

		dbgEnter "Fetcher.fetchAll"
		lNodes = Array.from(@all())
		dbgReturn "Fetcher.fetchAll", lNodes
		return lNodes

	# ..........................................................

	fetchUntil: (func, endLineOption) ->

		dbgEnter "Fetcher.fetchUntil", func, endLineOption
		assert (endLineOption=='keepEndLine') \
			|| (endLineOption=='discardEndLine'),
			"bad end line option: #{OL(endLineOption)}"
		lNodes = []
		for hNode from @allUntil(func, endLineOption)
			lNodes.push hNode
		dbgReturn "Fetcher.fetchUntil", lNodes
		return lNodes

	# ..........................................................
	# --- fetch a block

	fetchBlock: () ->

		dbgEnter "Fetcher.fetchBlock"
		lNodes = Array.from(@all())
		result = @nodesToBlock(lNodes)
		dbgReturn "Fetcher.fetchBlock", result
		return result

	# ..........................................................

	fetchBlockUntil: (func, endLineOption) ->

		dbgEnter "Fetcher.fetchBlockUntil"
		assert (endLineOption=='keepEndLine') \
			|| (endLineOption=='discardEndLine'),
			"bad end line option: #{OL(endLineOption)}"
		lNodes = @fetchUntil(func, endLineOption)
		result = @nodesToBlock(lNodes)
		dbgReturn "Fetcher.fetchBlockUntil", result
		return result

	# ..........................................................

	nodesToBlock: (lNodes) ->

		lStrings = []
		for hNode in lNodes
			line = hNode.getLine(@oneIndent)
			assert isString(line), "getLine() returned #{OL(line)}"
			lStrings.push line
		lNewStrings = undented(lStrings)
		assert isArray(lNewStrings),
			"undented returned #{OL(lNewStrings)} when given #{OL(lStrings)}"
		return arrayToBlock(lNewStrings)

