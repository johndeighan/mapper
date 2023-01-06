# Fetcher.coffee

import {assert} from '@jdeighan/base-utils/exceptions'
import {
	isString, isNonEmptyString, isInteger, isHash, isIterable, isFunction,
	isEmpty, nonEmpty, getOptions, toArray, toBlock,
	undef, defined, notdefined, rtrim, OL,
	} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn, dbgYield, dbgResume,
	} from '@jdeighan/base-utils/debug'
import {
	indentLevel, splitLine, getOneIndent, undented, isUndented,
	} from '@jdeighan/coffee-utils/indent'
import {parseSource, slurp} from '@jdeighan/coffee-utils/fs'

import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------
# 1. implement fetch() and peek()
# 2. handle extension lines
# 3. define init() - to override
# 4. implement fetchLinesAtLevel(level)
# 5. define extSep(str, nextStr) - to override
# 6. implement generator allNodes()
# 7. define procNode() - to override
# 8. implement getBlock(oneIndent)
# 9. define finalizeBlock() - to override

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

		@refill()    # sets @nextLevel and @nextStr
		@nextNode = @fetchNextNode()

		@init()   # option for additional initialization
		dbgReturn "Fetcher"

	# ..........................................................

	refill: () ->

		# --- invoke iterator to fill in @nextLevel & @nextStr
		{value, done} = @iterator.next()
		if done
			@nextLevel = 0
			@nextStr = undef
		else if isString(value)
			if (value == '__END__')
				@nextLevel = 0
				@nextStr = undef
			else
				[@nextLevel, @nextStr] = splitLine(value, @oneIndent)

				# --- Try to set @oneIndent
				if notdefined(@oneIndent) && (@nextLevel > 0)
					# --- will return undef if no indentation
					@oneIndent = getOneIndent(value)
		else
			@nextLevel = 0
			@nextStr = value
		return

	# ..........................................................

	init: () ->

		return

	# ..........................................................
	# --- returns hNode with keys:
	#        source
	#        str
	#        srcLevel - level in source code
	#        level    - includes added levels when #include'ing
	# --- OR undef at EOF

	fetch: () ->

		dbgEnter "Fetcher.fetch"

		if defined(@nextNode)
			save = @nextNode
			@nextNode = @fetchNextNode()
			dbg "return look ahead node"
			dbgReturn 'Fetcher.fetch', save
			return save

		dbgReturn "Fetcher.fetch", undef
		return undef

	# ..........................................................

	peek: () ->

		dbgEnter "Fetcher.peek"

		if defined(@nextNode)
			dbgReturn 'Fetcher.peek', @nextNode
			return @nextNode
		dbgReturn 'Fetcher.peek', undef
		return undef

	# ..........................................................

	fetchLinesAtLevel: (level) ->

		dbgEnter "TreeMapper.fetchLinesAtLevel", level
		lLines = []
		while defined(hNode = @peek()) \
				&& (hNode.isEmptyLine() || (hNode.level >= level))
			@fetch()
			lLines.push hNode.str
		dbgReturn "TreeMapper.fetchLinesAtLevel", lLines
		return lLines

	# ..........................................................

	fetchBlockAtLevel: (level) ->

		dbgEnter "TreeMapper.fetchBlockAtLevel", level
		block = toBlock(undented(@fetchLinesAtLevel(level)))
		dbgReturn "TreeMapper.fetchBlockAtLevel", block
		return block

	# ..........................................................
	# --- Returns the next available Node
	#        - hNode.str includes any extension lines

	fetchNextNode: () ->

		dbgEnter 'Fetcher.fetchNextNode'

		if notdefined(@nextStr)
			# --- indicates EOF
			dbg 'at EOF'
			dbgReturn 'Fetcher.fetchNextNode', undef
			return undef

		# --- Save current values, then refill
		level = @nextLevel
		str = @nextStr
		@refill()
		@lineNum += 1
		dbg "INC lineNum to #{@lineNum}"

		# --- save current line number in case there are extension lines
		orgLineNum = @lineNum
		dbg 'orgLineNum', orgLineNum

		if isNonEmptyString(str)
			# --- Check for extension lines
			while isNonEmptyString(@nextStr) && (@nextLevel >= level+2)
				str += @extSep(str, @nextStr) + @nextStr
				@refill()
				@lineNum += 1
				dbg "INC lineNum to #{@lineNum}"

			if (@addLevel > 0)
				dbg "add additional level #{@addLevel}"
				level += @addLevel

		dbg "create Node object"

		assert isUndented(str), "fetchNextNode: str not undented"
		hNode = new Node({
			str
			level
			source: @sourceInfoStr(orgLineNum),
			})

		dbgReturn "Fetcher.fetchNextNode", hNode
		return hNode

	# ..........................................................

	extSep: (str, nextStr) ->
		# --- can be overridden

		return ' '

	# ..........................................................

	sourceInfoStr: (lineNum=undef) ->
		# --- override in FetcherInc

		dbgEnter 'Fetcher.sourceInfoStr', lineNum
		if defined(lineNum)
			assert isInteger(lineNum), "Bad lineNum: #{OL(lineNum)}"
			result = "#{@hSourceInfo.filename}/#{lineNum}"
		else
			result = "#{@hSourceInfo.filename}"
		dbgReturn 'Fetcher.sourceInfoStr', result
		return result

	# ..........................................................
	# --- GENERATOR

	allNodes: () ->

		dbgEnter "Fetcher.allNodes"

		while defined(hNode = @fetch())
			dbg 'hNode', hNode
			if @procNode(hNode)
				dbgYield "Fetcher.allNodes", hNode
				yield hNode
				dbgResume "Fetcher.allNodes"

		dbgReturn "Fetcher.allNodes"
		return

	# ..........................................................

	procNode: (hNode) ->
		# --- does nothing, but can be overridden to
		#     add additional node processing
		# --- return value is true to keep the node, false to discard

		assert defined(hNode), "hNode not defined"
		return true

	# ..........................................................

	getBlock: (oneIndent="\t") ->

		dbgEnter "Fetcher.getBlock", oneIndent
		lLines = []
		for hNode from @allNodes()
			dbg 'GOT hNode', hNode
			line = hNode.getLine({oneIndent})
			dbg "line = #{OL(line)}"
			lLines.push line
		result = @finalizeBlock undented(toBlock(lLines))
		dbgReturn "Fetcher.getBlock", result
		return result

	# ..........................................................

	finalizeBlock: (block) ->

		return block
