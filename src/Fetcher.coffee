# Fetcher.coffee

import fs from 'fs'

import {LOG, LOGVALUE, assert, croak} from '@jdeighan/base-utils'
import {getOptions} from '@jdeighan/base-utils/utils'
import {
	dbg, dbgEnter, dbgReturn, dbgYield, dbgResume,
	} from '@jdeighan/base-utils/debug'
import {
	undef, pass, OL, rtrim, defined, notdefined,
	escapeStr, isString, isHash, isArray, isInteger,
	isFunction, isIterable, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {
	splitPrefix, indentLevel, undented,
	} from '@jdeighan/coffee-utils/indent'
import {toBlock, toArray} from '@jdeighan/coffee-utils/block'
import {
	parseSource, slurp, isSimpleFileName, isDir, pathTo,
	} from '@jdeighan/coffee-utils/fs'

import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------
#   class Fetcher
#      - sets @hSourceInfo
#      - fetch()
#      - handles extension lines
#      - removes trailing WS from strings
#      - stops at __END__
#      - all() - generator
#      - allUntil() - generator

export class Fetcher

	constructor: (hInput, options={}) ->

		dbgEnter "Fetcher", hInput, options

		# --- We need to set:
		#        @hSourceInfo - information about the source of input
		#        @iterator    - must be an iterator

		# --- hInput can be a plain string,
		#     or a hash with keys 'source' and/or 'content'
		if isString(hInput)
			@hSourceInfo = { filename: '<unknown>' }
			content = hInput
		else
			assert isHash(hInput), "not a hash: #{OL(hInput)}"
			{source, content} = hInput
			assert defined(source) || defined(content),
					"No source or content"
			if defined(source)
				@hSourceInfo = parseSource(source)
			else
				dbg "No source, so filename is <unknown>"
				@hSourceInfo = {filename: '<unknown>'}

			if ! defined(content)
				dbg "No content - check for fullpath"
				fullpath = @hSourceInfo.fullpath
				assert fullpath, "No content and no fullpath"
				dbg "slurping #{fullpath}"
				content = slurp(fullpath)

		# --- @hSourceInfo must exist and have a filename key
		dbg 'hSourceInfo', @hSourceInfo
		assert @hSourceInfo.filename, "parseSource returned no filename"

		# --- content must be iterable
		if isString(content)
			content = toArray(content)
		assert isIterable(content), "content not iterable"
		@iterator = content[Symbol.iterator]()

		# --- Handle options
		{addLevel} = getOptions(options)
		@addLevel = addLevel || 0

		@lookahead = undef   # if defined, [level, str]
		@numBlankLines = 0   # num blank lines to return before lookahead
		@altInput = undef    # implements #include
		@lineNum = 0
		@oneIndent = undef   # set from 1st line with indentation
		@forcedEOF = false

		@init()
		dbgReturn "Fetcher"

	# ..........................................................

	init: () ->

		return

	# ..........................................................
	# --- returns [level, str] or [undef, undef]
	#     handles:
	#        return lookahead if defined
	#        return undef if __END__ previously found
	#        return undef if iterator at EOF
	#        check for __END__
	#        Determine level, set @oneIndent if possible

	fetchLine: () ->

		dbgEnter "Fetcher.fetchLine"

		# --- return any blank lines
		if (@numBlankLines > 0)
			dbg "found #{@numBlankLines} blank lines"
			@numBlankLines =- 1
			@incLineNum()
			dbgReturn "Fetcher.fetchLine", ''
			return [0, '']

		# --- return anything in @lookahead,
		#     even if @forcedEOF is true
		if defined(@lookahead)
			dbg "found lookahead"
			result = @lookahead
			@lookahead = undef
			@incLineNum()
			dbgReturn "Fetcher.fetchLine", result
			return result

		dbg "no lookahead"

		if @forcedEOF
			dbg "forced EOF"
			dbgReturn "Fetcher.fetchLine", [undef, undef]
			return [undef, undef]

		dbg "not at forced EOF"

		{value: line, done} = @iterator.next()
		dbg "iterator returned", {line, done}
		if (done)
			dbg "iterator DONE"
			dbgReturn "Fetcher.fetchLine", [undef, undef]
			return [undef, undef]

		assert isString(line), "line is #{OL(line)}"
		if lMatches = line.match(/^(\s*)__END__$/)
			[_, prefix] = lMatches
			assert (prefix == ''), "__END__ should be at level 0"
			@forceEOF()
			dbg "found __END__"
			dbgReturn "Fetcher.fetchLine", [undef, undef]
			return [undef, undef]

		@incLineNum()
		[prefix, str] = splitPrefix(line)

		# --- Determine level
		if (prefix == '')
			level = 0
		else if defined(@oneIndent)
			level = indentLevel(prefix, @oneIndent)
		else
			# --- Set @oneIndent
			if lMatches = prefix.match(/^\t+$/)
				@oneIndent = "\t"
				level = prefix.length
			else
				@oneIndent = prefix
				level = 1
			dbg "oneIndent", @oneIndent

		assert (prefix == '') || defined(@oneIndent),
				"Bad prefix #{OL(prefix)}"

		result = [level, str]
		dbgReturn "Fetcher.fetchLine", result
		return result

	# ..........................................................
	# --- returns hNode with keys:
	#        source
	#        lineNum
	#        str
	#        srcLevel - level in source code
	#        level    - includes added levels when #include'ing

	fetch: () ->

		dbgEnter "Fetcher.fetch"

		# --- Check if data available from @altInput

		if defined(@altInput)
			dbg "has altInput"
			hNode = @altInput.fetch()

			# --- NOTE: hNode.str will never be #include
			#           because altInput's fetch would handle it

			if defined(hNode)
				# --- NOTE: altInput was created knowing how many levels
				#           to add due to indentation in #include statement
				assert hNode instanceof Node, "Not a Node: #{OL(hNode)}"
				dbg "from alt"
				dbgReturn "Fetcher.fetch", hNode
				return hNode

			# --- alternate input is exhausted
			@altInput = undef
			dbg "alt EOF"
		else
			dbg "there is no altInput"

		# --- At EOF, @fetchLine() returns [undef, undef]
		[level, str] = @fetchLine()
		assert notdefined(@lookahead),
				"lookahead after fetchLine: #{OL(@lookahead)}"

		if notdefined(str)
			dbgReturn "Fetcher.fetch", undef
			return undef

		assert isString(str), "not a string: #{OL(str)}"

		# --- Handle extension lines

		actualLineNum = @lineNum   # save current line number

		[nextLevel, nextStr] = @fetchLine()
		while defined(nextStr) && (nextLevel >= level+2)
			str += @extSep(str, nextStr) + nextStr
			[nextLevel, nextStr] = @fetchLine()

		if defined(nextStr)
			if (nextStr == '')
				dbg "inc numBlankLines"
				@numBlankLines += 1
			else
				dbg "set lookahead", [nextLevel, nextStr]
				@lookahead = [nextLevel, nextStr]
			dbg "dec lineNum"
			@decLineNum()

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
		else
			dbg "no #include"

		dbg "create Node object"
		hNode = new Node({
			str:     str
			level:   level + @addLevel
			source:  @sourceInfoStr(actualLineNum),
			lineNum: actualLineNum,
			})

		dbgReturn "Fetcher.fetch", hNode
		return hNode

	# ..........................................................

	sourceInfoStr: (lineNum) ->

		if defined(lineNum)
			assert isInteger(lineNum), "Bad lineNum: #{OL(lineNum)}"
		else
			lineNum = @lineNum

		lParts = []
		lParts.push "#{@hSourceInfo.filename}/#{lineNum}"
		if defined(@altInput)
			lParts.push @altInput.sourceInfoStr()
		return lParts.join(' ')

	# ..........................................................

	extSep: (str, nextStr) ->

		return ' '

	# ..........................................................

	createAltInput: (fname, level) ->

		dbgEnter "Fetcher.createAltInput", fname, level

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

		@altInput = new Fetcher({source: fullpath}, {addLevel: level})
		dbgReturn "Fetcher.createAltInput"
		return

	# ..........................................................

	incLineNum: (inc=1) ->

		dbgEnter "Fetcher.incLineNum", inc
		@lineNum += inc
		dbg "lineNum = #{@lineNum}"
		dbgReturn "Fetcher.incLineNum"
		return

	# ..........................................................

	decLineNum: (dec=1) ->

		dbgEnter "Fetcher.decLineNum", dec
		@lineNum -= dec
		dbg "lineNum = #{@lineNum}"
		dbgReturn "Fetcher.decLineNum"
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

	allUntil: (func, options={}) ->
		# --- stop when func(hNode) returns true

		dbgEnter "Fetcher.allUntil", func, options
		assert isFunction(func), "Arg 1 not a function"
		{keepEndLine} = getOptions(options)

		for hNode from @all()
			assert defined(hNode), "BAD - hNode is undef in allUntil()"
			if func(hNode)
				# --- When func returns true, we're done
				#     We don't return hNode, but might save it
				if keepEndLine
					@lookahead = hNode
				dbgReturn "Fetcher.allUntil"
				return

			dbgYield "Fetcher.allUntil", hNode
			yield hNode
			dbgResume "Fetcher.allUntil"


		dbgReturn "Fetcher.allUntil"
		return

	# ..........................................................

	getBlockUntil: (func, options={}) ->

		dbgEnter "Fetcher.getBlockUntil"
		{oneIndent} = getOptions(options)
		lLines = []
		for hNode from @allUntil(func, options)
			lLines.push hNode.getLine(oneIndent)  # uses TAB if undef
		result = toBlock(lLines)
		dbgReturn "Fetcher.getBlockUntil", result
		return result

	# ..........................................................

	getBlock: (options={}) ->

		dbgEnter "Fetcher.getBlock"
		{oneIndent} = getOptions(options)
		lLines = []
		for hNode from @all()
			lLines.push hNode.getLine(oneIndent)
		result = @finalizeBlock(toBlock(lLines))
		dbgReturn "Fetcher.getBlock", result
		return result

	# ..........................................................

	finalizeBlock: (block) ->

		return block
