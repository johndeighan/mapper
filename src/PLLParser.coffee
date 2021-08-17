# PLLParser.coffee

import {strict as assert} from 'assert'

import {
	say, undef, error, isArray, isFunction, isEmpty,
	escapeStr,
	} from '@jdeighan/coffee-utils'
import {splitLine} from '@jdeighan/coffee-utils/indent'
import {
	numHereDocs, patch, build,
	} from '@jdeighan/coffee-utils/heredoc'
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

	getHereDocs: (line, orgLineNum) ->

		n = numHereDocs(line)
		lSections = []     # --- will have one subarray for each HEREDOC
		# --- NOTE: [1..n] doesn't work here ?????
		for i in [0...n]
			lLines = []
			while (@lBuffer.length > 0) && not isEmpty(@lBuffer[0])
				lLines.push @fetch()
			if (@lBuffer.length == 0)
				error """
						EOF while processing HEREDOC
						at line #{orgLineNum}
						'#{escapeStr(line)}'
						n = #{n}
						"""
			else
				@fetch()   # empty line
			lSections.push lLines

		return lSections

	# ..........................................................

	patchLine: (line, lSections) ->

		return patch(line, lSections)

	# ..........................................................

	handleEmptyLine: (lineNum) ->

		return undef      # skip blank lines by default

	# ..........................................................

	mapString: (str) ->

		return str

	# ..........................................................

	mapLine: (orgLine) ->

		assert orgLine?, "mapLine(): orgLine is undef"
		if isEmpty(orgLine)
			return @handleEmptyLine(@lineNum)

		[level, line] = splitLine(orgLine)
		orgLineNum = @lineNum

		# --- Merge in any continuation lines
		lContLines = @getContLines(level)
		line = @joinContLines(line, lContLines)

		# --- handle HEREDOCs

		lSections = @getHereDocs(line, orgLineNum)
		if (lSections.length > 0)
			line = @patchLine(line, lSections)

		mapped = @mapString(line)
		return [level, orgLineNum, mapped]

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
