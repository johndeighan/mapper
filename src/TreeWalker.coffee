# TreeWalker.coffee

import {
	assert, undef, croak, defined, OL, rtrim,
	isString, isNumber, isEmpty, nonEmpty, isArray, isHash,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {
	splitLine, indentLevel, indented, undented,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Mapper} from '@jdeighan/mapper'
import {lineToParts, mapHereDoc} from '@jdeighan/mapper/heredoc'

# ===========================================================================
#   class TreeWalker
#      - map() returns {uobj, level, lineNum} or undef
#   to use, override:
#      mapStr(str, level) - returns user object, default returns str
#      handleCmd()
#      beginWalk() -
#      visit(uobj, level, lineNum) -
#      endVisit(uobj, level, lineNum) -
#      endWalk() -

export class TreeWalker extends Mapper

	# ..........................................................
	# --- Should always return either:
	#        undef
	#        object with {uobj, level, lineNum}
	# --- Will only receive non-special lines

	map: (line) ->

		debug "enter TreeWalker.map()", line

		# --- a TreeWalker makes no sense unless items are strings
		assert isString(line), "non-string: #{OL(line)}"

		lineNum = @lineNum    # so extension lines aren't counted
		[level, str] = splitLine(line)
		debug "split: str = #{OL(str)}, level = #{level}"
		assert nonEmpty(str), "empty string should be special"

		# --- check for extension lines
		debug "check for extension lines"
		lExtLines = @fetchLinesAtLevel(level+2)
		assert isArray(lExtLines), "lExtLines not an array"
		str = @joinExtensionLines(str, lExtLines)

		debug "call super"
		str = super(str)      # performs variable replacement
		debug "from super", str

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			hResult = @handleHereDoc(str, level)
			if (hResult.line != str)
				str = hResult.line
				debug "line becomes #{OL(str)}"


		# --- NOTE: mapStr() may return undef, meaning to ignore
		uobj = @mapStr(str, level)
		if defined(uobj)
			result = {uobj, level, lineNum}
			debug "return from TreeWalker.map()", result
			return result
		else
			debug "return undef from TreeWalker.map()"
			return undef

	# ..........................................................

	joinExtensionLines: (line, lExtLines) ->

		# --- There might be empty lines in lExtLines
		#     but we'll skip them here
		for contLine in lExtLines
			if nonEmpty(contLine)
				line += ' ' + contLine.trim()
		return line

	# ..........................................................

	handleHereDoc: (line, level) ->
		# --- Indentation has been removed from line
		# --- Find each '<<<' and replace with result of mapHereDoc()

		debug "enter handleHereDoc(level=#{OL(level)})", line
		assert isString(line), "not a string"
		lParts = lineToParts(line)
		debug 'lParts', lParts
		lObjects = []
		lNewParts = for part in lParts
			if part == '<<<'
				lLines = @getHereDocLines(level+1)
				debug 'lLines', lLines
				hResult = mapHereDoc(arrayToBlock(lLines))
				debug 'hResult', hResult
				lObjects.push hResult.obj
				hResult.str
			else
				part    # keep as is

		hResult = {
			line: lNewParts.join('')
			lParts: lParts
			lObjects: lObjects
			}

		debug "return from handleHereDoc", hResult
		return hResult

	# ..........................................................

	getHereDocLines: (atLevel) ->
		# --- Get all lines until addHereDocLine() returns undef
		#     atLevel will be one greater than the indent
		#        of the line containing <<<

		debug "enter TreeWalker.getHereDocLines()"
		assert atLevel > 0, "atLevel = #{OL(atLevel)}, should not be 0"
		lLines = @fetchLinesAtLevel(atLevel, '') # stop on blank line
		assert isArray(lLines), "lLines not an array"
		result = undented(lLines, atLevel)
		debug "return from TreeWalker.getHereDocLines()", result
		return result

	# ..........................................................

	extSep: (str, nextStr) ->

		return ' '

	# ..........................................................

	isEmptyHereDocLine: (str) ->

		return (str == '.')

	# ..........................................................
	# --- designed to override

	mapStr: (str, level) ->

		return str

	# ..........................................................

	unmap: (h) ->

		croak "TreeWalker.unmap() called!"

	# ..........................................................

	handleEmptyLine: (line) ->

		return undef    # remove empty lines

	# ..........................................................

	handleComment: (line) ->

		# --- line includes any indentation
		[level, uobj] = splitLine(line)
		return {uobj, level, lineNum: @lineNum}

	# ..........................................................
	# --- We don't define any new commands, but
	#     we need to determine level from indentation

	handleCmd: (h) ->

		debug "enter TreeWalker.handleCmd()"
		result = super h
		if (result == undef)
			debug "return undef from TreeWalker.handleCmd() - super undef"
			return undef
		assert isString(result), "TreeWalker non-string #{OL(result)}"

		[level, uobj] = splitLine(result)
		result = {uobj, level, lineNum: @lineNum}
		debug "return from TreeWalker.handleCmd()", result
		return result

	# ..........................................................

	fetchLinesAtLevel: (atLevel, stopOn=undef) ->
		# --- Does NOT remove any indentation

		debug "enter TreeWalker.fetchLinesAtLevel(#{OL(atLevel)}, #{OL(stopOn)})"
		assert (atLevel > 0), "atLevel is 0"
		lLines = []
		while defined(item = @fetch()) \
				&& debug("item = #{OL(item)}") \
				&& isString(item) \
				&& ((stopOn == undef) || (item != stopOn)) \
				&& debug("OK") \
				&& (isEmpty(item) || (indentLevel(item) >= atLevel))

			debug "push #{OL(item)}"
			lLines.push item

		# --- Cases:                            unfetch?
		#        1. item is undef                 NO
		#        2. item not a string             YES
		#        3. item == stopOn (& defined)    NO
		#        4. item nonEmpty and undented    YES

		if ((item == undef) || (item == stopOn))
			debug "don't unfetch"
		else
			debug "do unfetch"
			@unfetch item

		debug "return from TreeWalker.fetchLinesAtLevel()", lLines
		return lLines

	# ..........................................................

	fetchBlockAtLevel: (atLevel, stopOn=undef) ->

		debug "enter TreeWalker.fetchBlockAtLevel(#{OL(atLevel)})"
		lLines = @fetchLinesAtLevel(atLevel, stopOn)
		debug 'lLines', lLines
		lLines = undented(lLines, atLevel)
		debug "undented lLines", lLines
		result = arrayToBlock(lLines)
		debug "return from TreeWalker.fetchBlockAtLevel()", result
		return result

	# ..........................................................
	# --- override these for tree walking

	beginWalk: () ->

		return undef

	# ..........................................................

	visit: (uobj, level, lineNum) ->

		return indented(uobj, level)

	# ..........................................................

	endVisit:  (uobj, level, lineNum) ->

		return undef

	# ..........................................................

	endWalk: () ->

		return undef

	# ..........................................................

	addLine: (line) ->

		if (line == undef)
			return
		if isArray(line)
			@lLines.push line...
		else
			@lLines.push line
		return

	# ..........................................................

	walk: () ->

		debug "enter walk()"

		# --- stack of {
		#        node: {uobj, level, lineNum},
		#        userhash: {}
		#        }
		lStack = []

		# --- resulting lines
		@lLines = []

		@addLine(@beginWalk())

		for node from @allMapped()
			while (lStack.length > node.level)
				hInfo = lStack.pop()
				{uobj, level, lineNum} = hInfo.node
				@addLine(@endVisit(uobj, level, lineNum, hInfo.userhash))

			hInfo = {
				node
				userhash: {}
				}
			{uobj, level, lineNum} = node
			@addLine(@visit(uobj, level, lineNum, hInfo.userhash))
			lStack.push hInfo
		while (lStack.length > 0)
			hInfo = lStack.pop()
			{uobj, level, lineNum} = hInfo.node
			@addLine(@endVisit(uobj, level, lineNum, hInfo.userhash))

		@addLine(@endWalk())
		result = arrayToBlock(@lLines)
		debug "return from walk()", result
		return result

	# ..........................................................

	getBlock: () ->

		debug "enter getBlock()"
		result = @walk()
		debug "return from getBlock()", result
		return result

# ---------------------------------------------------------------------------

export class TraceWalker extends TreeWalker

	# ..........................................................
	#     builds a trace of the tree
	#        which is returned by endWalk()

	beginWalk: () ->

		@lTrace = ["begin"]   # an array of strings
		return

	# ..........................................................

	visit: (uobj, level, lineNum) ->

		@lTrace.push "|.".repeat(level) + "> #{OL(uobj)}"
		return

	# ..........................................................

	endVisit: (uobj, level, lineNum) ->

		@lTrace.push "|.".repeat(level) + "< #{OL(uobj)}"
		return

	# ..........................................................

	endWalk: () ->

		@lTrace.push "end"
		block = arrayToBlock(@lTrace)
		@lTrace = undef
		return block

