# Mapper.coffee

import {
	assert, undef, croak, isString, isEmpty, nonEmpty, OL,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {
	splitLine, indented, indentLevel,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'

import {LineFetcher} from '@jdeighan/mapper/fetcher'

# ===========================================================================
#   class Mapper
#      - keep track of indentation
#      - allow mapping of lines, including skipping lines
#      - implement look ahead via peekPair()

export class Mapper extends LineFetcher

	constructor: (source, content) ->

		super source, content
		@lLookAhead = []

		# --- cache in case getAllPairs() is called multiple times
		#     each pair is [<mapped str>, <level>]
		@lAllPairs = undef

	# ..........................................................

	getPair: () ->

		debug "enter Mapper.getPair() - from #{@filename}"
		if @lLookAhead.length > 0
			pair = @lLookAhead.shift()
			debug "return lookahead pair from Mapper.getPair()", pair
			return pair

		line = @fetch()    # will handle #include
		debug "FETCH LINE", line

		if ! line?
			debug "return undef from Mapper.getPair() - at EOF"
			return undef

		[level, str] = splitLine(line)
		assert indentLevel(str)==0, "splitLine() returned indented str"
		assert str? && isString(str), "Mapper.getPair(): not a string"
		result = @mapLine(str, level)
		debug "MAP: '#{str}' => #{OL(result)}"

		# --- if mapLine() returns undef, we skip that line

		while ! result? && ! @eof()
			line = @fetch()
			[level, str] = splitLine(line)
			assert indentLevel(str)==0, "splitLine() returned indented str"
			result = @mapLine(str, level)
			debug "MAP: '#{str}' => #{OL(result)}"

		lResult = [result, level]
		debug "return from Mapper.getPair()", lResult
		return lResult

	# ..........................................................

	ungetPair: (lPair) ->
		# --- lPair will always be [<item>, <level>]
		#     <item> can be anything - i.e. it's been mapped

		debug 'enter ungetPair()', lPair
		@lLookAhead.unshift lPair
		debug 'return from ungetPair()'
		return

	# ..........................................................

	peekPair: () ->

		debug 'enter peekPair():'
		if @lLookAhead.length > 0
			pair = @lLookAhead[0]
			debug "return lookahead from peekPair()", pair
			return pair
		lPair = @getPair()
		if ! lPair?
			debug "return undef from peekPair() - getPair() returned undef"
			return undef
		@ungetPair(lPair)
		debug "return #{OL(lPair)} from peekPair()"
		return lPair

	# ..........................................................

	skipPair: () ->

		debug 'enter skipPair():'
		if @lLookAhead.length > 0
			@lLookAhead.shift()
			debug "return from skipPair(): remove lookahead"
			return
		@getPair()
		debug 'return from skipPair()'
		return

	# ..........................................................
	# --- designed to override with a mapping method
	#     which can map to any valid JavaScript value

	mapLine: (line, level) ->

		return line

	# ..........................................................
	# --- Fetch a block of text at level or greater than 'level'
	#     as one long string
	# --- Designed to use in mapLine()

	fetchBlock: (atLevel) ->

		debug "enter Mapper.fetchBlock(#{atLevel})"
		lLines = []

		line = undef
		while (line = @fetch())?
			debug "LINE IS #{OL(line)}"
			assert isString(line),
				"Mapper.fetchBlock() - not a string: #{OL(line)}"
			if isEmpty(line)
				debug "empty line"
				lLines.push ''
				continue
			[level, str] = splitLine(line)
			assert indentLevel(str)==0,
				"Mapper.fetchBlock(): splitLine() returned indented str"
			debug "LOOP: level = #{level}, str = #{OL(str)}"
			if (level < atLevel)
				@unfetch(line)
				debug "RESULT: unfetch the line"
				break
			assert level >= atLevel, "Mapper.fetchBlock(): bad level"
			result = indented(str, level-atLevel)
			debug "RESULT", result
			lLines.push result

		block = arrayToBlock(lLines)
		debug "return from Mapper.fetchBlock()", block
		return block

	# ..........................................................

	getAllPairs: () ->

		debug "enter Mapper.getAllPairs()"
		if @lAllPairs?
			debug "return cached lAllPairs from Mapper.getAllPairs()"
			return @lAllPairs

		# --- Each pair is [<result>, <level>],
		#     where <result> can be anything
		lPairs = []
		while (lPair = @getPair())?
			debug "GOT PAIR", lPair
			lPairs.push lPair
		@lAllPairs = lPairs   # cache
		debug "return from Mapper.getAllPairs()", lPairs
		return lPairs

	# ..........................................................

	getBlock: () ->
		# --- You can only call getBlock() if mapLine() always
		#     returns undef or a string

		debug "enter Mapper.getBlock()"
		lLines = []
		for [line, level] in @getAllPairs()
			if line?
				assert isString(line),
						"getBlock(): got non-string '#{OL(line)}'"
				lLines.push indented(line, level)
		block = arrayToBlock(lLines)
		debug "return from Mapper.getBlock()", block
		return block

# ===========================================================================

export doMap = (inputClass, source, text) ->

	assert inputClass?, "Missing input class"
	if lMatches = inputClass.toString().match(/class\s+(\w+)/)
		className = lMatches[1]
	else
		croak "doMap(): Bad input class"
	debug "enter doMap(#{className}) source='#{source}'"
	oInput = new inputClass(source, text)
	assert oInput instanceof Mapper,
		"doMap() requires a Mapper or subclass"
	result = oInput.getBlock()
	debug "return from doMap()", result
	return result
