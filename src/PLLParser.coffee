# PLLParser.coffee

import {strict as assert} from 'assert'

import {say, undef, error, isArray, isFunction} from '@jdeighan/coffee-utils'
import {splitLine} from '@jdeighan/coffee-utils/indent'
import {StringInput} from '@jdeighan/string-input'

# ---------------------------------------------------------------------------
# --- To derive a class from this:
#        1. Extend this class
#        2. Override mapString(), which gets the line with
#           any continuation lines appended

export class PLLInput extends StringInput

	mapString: (str) ->
		return str

	mapLine: (line) ->
		assert line?, "mapLine(): line is undef"
		[level, str] = splitLine(line)
		orgLineNum = @lineNum

		# --- Merge in any continuation lines
		while (nextLine = @fetch()) \
				&& ([nextLevel, nextStr] = splitLine(nextLine)) \
				&& (nextLevel >= level+2)
			str += ' ' + nextStr
		if nextLine
			@unfetch nextLine

		return [level, orgLineNum, @mapString(str)]

	getTree: () ->

		return treeify(@getAll())

# ---------------------------------------------------------------------------

export parsePLL = (contents, mapper) ->

	oInput = new PLLInput(contents, mapper)
	return oInput.getTree()

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
