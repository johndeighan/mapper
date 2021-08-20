# PLLParser.coffee

import {strict as assert} from 'assert'

import {
	say, undef, error, isArray, isFunction, isEmpty, isComment,
	escapeStr, isTAML, taml,
	} from '@jdeighan/coffee-utils'
import {splitLine, undentedBlock} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'
import {StringInput} from '@jdeighan/string-input'

# ---------------------------------------------------------------------------
# --- To derive a class from this:
#        1. Extend this class
#        2. Override mapString(), which gets the line with
#           any continuation lines appended, plus any
#           HEREDOC sections
#        3. If desired, override patchLine, which patches
#           HEREDOC lines into the original string

export class PLLParser extends StringInput

	getContLines: (curlevel) ->

		lLines = []
		while (nextLine = @fetch()) \
				&& ([nextLevel, nextStr] = splitLine(nextLine)) \
				&& (nextLevel >= curlevel+2)
			lLines.push(nextStr)
		if nextLine
			# --- we fetched a line we didn't want
			@unfetch nextLine
		return lLines

	# ..........................................................

	joinContLines: (line, lContLines) ->

		for str in lContLines
			line += ' ' + str
		return line

	# ..........................................................
	# ..........................................................

	getHereDocLines: () ->
		# --- Get all lines until empty line is found
		#     BUT treat line of a single period as empty line

		orgLineNum = @lineNum
		lLines = []
		while (@lBuffer.length > 0) && not isEmpty(@lBuffer[0])
			line = @fetch()
			if line.match(/^\s*\.\s*$/)
				lLines.push ''
			else
				lLines.push line
		if (@lBuffer.length > 0)
			@fetch()   # empty line
		return lLines

	# ..........................................................

	heredocStr: (str) ->
		# --- return replacement string for '<<<'

		return str.replace(/\n/g, ' ')

	# ..........................................................

	patchLine: (line) ->
		# --- Find each '<<<' and replace with result of heredocStr()

		debug "enter patchLine('#{line}')"
		lParts = []     # joined at the end
		pos = 0
		while ((start = line.indexOf('<<<', pos)) != -1)
			lParts.push line.substring(pos, start)
			lLines = @getHereDocLines()
			if lLines? && (lLines.length > 0)
				lParts.push @heredocStr(undentedBlock(lLines))
			pos = start + 3

		if line.indexOf('<<<', pos) != -1
			error "patchLine(): Not all #{n} HEREDOC markers were replaced" \
				+ "in '#{line}'"
		lParts.push line.substring(pos, line.length)
		result = lParts.join('')
		debug "return '#{result}'"
		return result

	# ..........................................................

	handleEmptyLine: (lineNum) ->

		return undef      # skip blank lines by default

	# ..........................................................

	handleComment: (lineNum) ->

		return undef      # skip comments by default

	# ..........................................................

	mapString: (line, level) ->
		# --- NOTE: line has indentation removed

		return line

	# ..........................................................

	mapLine: (orgLine) ->

		assert orgLine?, "mapLine(): orgLine is undef"
		if isEmpty(orgLine)
			return @handleEmptyLine(@lineNum)

		if isComment(orgLine)
			return @handleComment(@lineNum)

		[level, line] = splitLine(orgLine)
		orgLineNum = @lineNum

		# --- Merge in any continuation lines
		lContLines = @getContLines(level)
		line = @joinContLines(line, lContLines)

		# --- handle HEREDOCs
		line = @patchLine(line)

		mapped = @mapString(line, level)
		if mapped?
			return [level, orgLineNum, mapped]
		else
			return undef

	# ..........................................................

	getTree: () ->

		return treeify(@getAll())

# ---------------------------------------------------------------------------
# Each item must be a sub-array with 3 items: [<level>, <lineNum>, <node>]

export treeify = (lItems, atLevel=0) ->
	# --- stop when an item of lower level is found, or at end of array

	lNodes = []
	while (lItems.length > 0) && (lItems[0][0] >= atLevel)
		item = lItems.shift()
		assert isArray(item), "treeify(): item is not an array"
		len = item.length
		assert len == 3, "treeify(): item has length #{len}"
		[level, lineNum, node] = item
		assert level==atLevel,
			"treeify(): item at level #{level}, should be #{atLevel}"
		h = {node, lineNum}
		body = treeify(lItems, atLevel+1)
		if body?
			h.body = body
		lNodes.push(h)
	if lNodes.length==0
		return undef
	else
		return lNodes
