# PLLParser.coffee

import {strict as assert} from 'assert'

import {say, undef, error, isArray, isFunction} from '@jdeighan/coffee-utils'
import {splitLine} from '@jdeighan/coffee-utils/indent'
import {StringInput, FileInput} from '@jdeighan/string-input'

# ---------------------------------------------------------------------------

class PLLInput extends StringInput

	constructor: (content, @mapper) ->

		super content
		if not isFunction(@mapper)
			error "new PLLInput(): mapper is not a function"

	mapLine: (line) ->
		assert line?, "mapLine(): line is undef"
		[level, str] = splitLine(line)

		# --- Merge in any continuation lines
		while (nextLine = @fetch()) \
				&& ([nextLevel, nextStr] = splitLine(nextLine)) \
				&& (nextLevel >= level+2)
			str += ' ' + nextStr
		if nextLine
			@unfetch nextLine

		return [level, @mapper(str)]

	getTree: () ->

		return treeify(@getAll())

# ---------------------------------------------------------------------------

export parsePLL = (contents, mapper) ->

	oInput = new PLLInput(contents, mapper)
	return oInput.getTree()

# ---------------------------------------------------------------------------
# Each item must be a sub-array with 2 items: [<level>, <node>]

export treeify = (lItems, level=0) ->
	# --- stop when an item of lower level is found, or at end of array

	lNodes = []
	while (lItems.length > 0) && (lItems[0][0] >= level)
		item = lItems.shift()
		assert isArray(item), "treeify(): item is not an array"
		len = item.length
		assert len == 2, "treeify(): item has length #{len}"
		[itemLevel, itemNode] = item
		assert itemLevel==level,
			"treeify(): item at level #{itemLevel}, should be #{level}"
		h = {node: itemNode}
		lChildren = treeify(lItems, level+1)
		if lChildren?
			h.lChildren = lChildren
		lNodes.push(h)
	if lNodes.length==0
		return undef
	else
		return lNodes
