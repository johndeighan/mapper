# Fetcher.coffee

import {assert} from '@jdeighan/base-utils/exceptions'
import {getOptions} from '@jdeighan/base-utils/utils'
import {
	dbg, dbgEnter, dbgReturn, dbgYield, dbgResume,
	} from '@jdeighan/base-utils/debug'
import {
	isString, isInteger, isHash, isIterable, isFunction,
	isEmpty, nonEmpty,
	undef, defined, notdefined, rtrim, OL,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, splitLine, getOneIndent, undented,
	} from '@jdeighan/coffee-utils/indent'
import {toArray, toBlock} from '@jdeighan/coffee-utils/block'
import {parseSource, slurp} from '@jdeighan/coffee-utils/fs'
import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------

export class Fetcher

	constructor: (hInput, options={}) ->
		# --- Valid options:
		#        addLevel - num of levels to add to each line
		#                   unless the line is empty

		dbgEnter "Fetcher", hInput, options

		# --- hInput can be:
		#        1. a plain string
		#        2. a hash with keys 'source' and/or 'content',
		#        3. an iterator

		# --- We need to set:
		#        @hSourceInfo - information about the source of input
		#        @iterator    - must be an iterator

		# --- Handle options
		{addLevel} = getOptions(options)
		@addLevel = addLevel || 0
		if (@addLevel > 0)
			dbg "add #{@addLevel} levels"

		if isString(hInput)
			dbg "string passed as hInput"
			@hSourceInfo = { filename: '<unknown>' }
			content = toArray(hInput)
			@iterator = content[Symbol.iterator]()
			dbg "iterator is an array with #{content.length} items"
		else if isHash(hInput)
			dbg "hash passed as hInput"
			{source, content} = hInput
			assert defined(source) || defined(content),
					"No source or content"
			if defined(source)
				@hSourceInfo = parseSource(source)
			else
				dbg "No source, so filename is <unknown>"
				@hSourceInfo = {filename: '<unknown>'}

			if defined(content)
				if isString(content)
					content = toArray(content)
					dbg "iterator is an array with #{content.length} items"
				assert isIterable(content), "content not iterable"
				@iterator = content[Symbol.iterator]()
			else
				dbg "No content - check for fullpath"
				fullpath = @hSourceInfo.fullpath
				assert nonEmpty(fullpath), "No content and no fullpath"

				# --- ultimately, we want to create an iterator here
				#     rather than blindly reading the entire file

				dbg "slurping #{fullpath}"
				content = toArray(slurp(fullpath))
				@iterator = content[Symbol.iterator]()
		else
			dbg "iterable passed as hInput"
			@hSourceInfo = { filename: '<unknown>' }
			assert isIterable(hInput), "hInput not iterable"
			@iterator = hInput[Symbol.iterator]()

		# --- @hSourceInfo must exist and have a filename key
		dbg 'hSourceInfo', @hSourceInfo
		assert nonEmpty(@hSourceInfo.filename),
			"parseSource returned no filename"

		@lineNum = 0
		@oneIndent = undef   # set from 1st line with indentation

		# --- invoke iterator to fill in @lookAheadLine
		{value, done} = @iterator.next()
		if done
			@lookAheadLine = undef
		else
			@lookAheadLine = value
		@lookAheadNode = @fetchNextNode()

		# --- This is set when a stopper func returns true
		#     Fetch will always return this next if it's set
		@fetchStopperNode = undef  # set

		# --- NOTE: There is always a @lookAheadLine,
		#           except when we reach EOF

		@init()   # option for additional initialization
		dbgReturn "Fetcher"

	# ..........................................................

	init: () ->

		return

	# ..........................................................
	# --- returns hNode with keys:
	#        source
	#        lineNum
	#        str
	#        srcLevel - level in source code
	#        level    - includes added levels when #include'ing
	# --- OR undef at EOF

	fetch: () ->

		dbgEnter "Fetcher.fetch"

		if defined(@fetchStopperNode)
			save = @fetchStopperNode
			@fetchStopperNode = undef
			dbg "return stopper node"
			dbgReturn 'Fetcher.fetch', save
			return save

		if defined(@lookAheadNode)
			save = @lookAheadNode
			@lookAheadNode = @fetchNextNode()
			dbg "return look ahead node"
			dbgReturn 'Fetcher.fetch', save
			return save

		dbgReturn "Fetcher.fetch", undef
		return undef

	# ..........................................................

	peek: () ->

		dbgEnter "Fetcher.peek"

		if defined(@fetchStopperNode)
			dbgReturn 'Fetcher.peek', @fetchStopperNode
			return @fetchStopperNode
		if defined(@lookAheadNode)
			dbgReturn 'Fetcher.peek', @lookAheadNode
			return @lookAheadNode
		dbgReturn 'Fetcher.peek', undef
		return undef

	# ..........................................................
	# --- Returns the next available Node
	#        - hNode.str includes any extension lines

	fetchNextNode: () ->

		dbgEnter 'Fetcher.fetchNextNode'
		next = @fetchNextStr()
		if notdefined(next)
			dbgReturn "Fetcher.fetchNextNode", undef
			return undef

		# --- NOTE: str is typically a string,
		#           but it can be an arbitrary JavaScript value
		[level, str] = next

		# --- save current line number in case there are extension lines
		orgLineNum = @lineNum
		dbg 'orgLineNum', orgLineNum

		if isString(str)
			# --- Check for extension lines
			while isString(@lookAheadLine) \
					&& (indentLevel(@lookAheadLine, @oneIndent) >= level+2)

				# --- since @lookAheadLine is defined,
				#     we know that @fetchNextStr() won't return undef

				[nextLevel, nextStr] = @fetchNextStr()
				str += @extSep(str, nextStr) + nextStr
			if isEmpty(str)
				newlevel = 0
			else
				newlevel = level + @addLevel
		else
			newlevel = 0

		dbg "create Node object"

		hNode = new Node({
			str
			level:   newlevel
			source:  @sourceInfoStr(orgLineNum),
			lineNum: orgLineNum,
			})

		dbgReturn "Fetcher.fetchNextNode", hNode
		return hNode

	# ..........................................................
	# --- Gets the next [level, str] (or undef), where
	#        - undef is returned at EOF
	#        - __END__ acts like EOF
	#        - if @oneIndent not initially set, set it if:
	#             - item is a string
	#             - item has indentation
	#        - @lineNum is incremented if not EOF

	fetchNextStr: () ->

		dbgEnter 'Fetcher.fetchNextStr'
		if notdefined(@lookAheadLine)
			# --- indicates EOF
			dbg 'lookAhead empty'
			dbgReturn 'Fetcher.fetchNextStr', undef
			return undef

		save = @lookAheadLine   # save for later return
		dbg '@lookAheadLine saved', save

		# --- Refill @lookAheadLine
		{value, done} = @iterator.next()
		if done
			dbg "iterator returned done = true"
			@lookAheadLine = undef   # we're at EOF
		else if isString(value) && (value == '__END__')
			dbg "found __END__"
			@lookAheadLine = undef   # we're at EOF
		else
			dbg "GOT #{OL(value)} from iterator, put in @lookAheadLine"
			@lookAheadLine = value

			# --- Try to set @oneIndent
			if notdefined(@oneIndent) && isString(value)
				# --- will return undef if no indentation
				@oneIndent = getOneIndent(value)

		@lineNum += 1
		dbg "INC lineNum to #{@lineNum}"

		if isString(save)
			result = splitLine(save, @oneIndent)
		else
			result = [0, save]
		dbgReturn 'Fetcher.fetchNextStr', result
		return result

	# ..........................................................

	extSep: (str, nextStr) ->
		# --- can be overridden

		return ' '

	# ..........................................................

	sourceInfoStr: (lineNum) ->
		# --- override in FetcherEx

		dbgEnter 'Fetcher.sourceInfoStr', lineNum
		assert isInteger(lineNum), "Bad lineNum: #{OL(lineNum)}"
		result = "#{@hSourceInfo.filename}/#{lineNum}"
		dbgReturn 'Fetcher.sourceInfoStr', result
		return result

	# ..........................................................
	# --- GENERATOR

	all: (stopperFunc=undef) ->
		# --- If you provide a stopper func, and you want to
		#     skip the line that you stop on,
		#     then you'll need to fetch it when done

		dbgEnter "Fetcher.all"

		while defined(hNode = @fetch())
			if defined(stopperFunc) && stopperFunc(hNode)
				@fetchStopperNode = hNode
				dbgReturn 'Fetcher.all'
				return
			dbgYield "Fetcher.all", hNode
			yield hNode
			dbgResume "Fetcher.all"
		dbgReturn "Fetcher.all"
		return

	# ..........................................................

	getBlock: (stopperFunc=undef, oneIndent="\t") ->

		dbgEnter "Fetcher.getBlock", stopperFunc, oneIndent
		lLines = []
		for hNode from @all(stopperFunc)
			dbg 'hNode', hNode
			lLines.push hNode.getLine({oneIndent})
		result = @finalizeBlock undented(toBlock(lLines))
		dbgReturn "Fetcher.getBlock", result
		return result

	# ..........................................................

	finalizeBlock: (block) ->

		return block
