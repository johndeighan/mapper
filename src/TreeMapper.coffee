# TreeMapper.coffee

import {
	undef, assert, croak, deepCopy, isString, isArray, isInteger,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'

import {CieloMapper} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# --- To derive a class from this:
#        1. Extend this class
#        2. Override mapNode(), which gets the line with
#           any continuation lines appended, plus any
#           HEREDOC sections expanded
#        3. If desired, override handleHereDoc, which patches
#           HEREDOC lines into the original string

export class TreeMapper extends CieloMapper

	constructor: (content, source) ->
		super content, source

		# --- Cached tree, in case getTree() is called multiple times
		@tree = undef

	# ..........................................................

	mapString: (line, level) ->

		result = @mapNode(line, level)
		if result?
			return [level, @lineNum, result]
		else
			# --- We need to skip over all following nodes
			#     at a higher level than this one
			@fetchBlock(level+1)
			return undef

	# ..........................................................

	mapNode: (line, level) ->

		return line

	# ..........................................................

	getAll: () ->

		# --- This returns a list of pairs, but
		#     we don't need the level anymore since it's
		#     also stored in the node

		lPairs = super()
		debug "lPairs", lPairs

		lItems = for pair in lPairs
			pair[0]
		debug "lItems", lItems
		return lItems

	# ..........................................................

	getTree: () ->

		debug "enter getTree()"
		if @tree?
			debug "return cached tree from getTree()"
			return @tree

		lItems = @getAll()

		assert lItems?, "lItems is undef"
		assert isArray(lItems), "getTree(): lItems is not an array"

		# --- treeify will consume its input, so we'll first
		#     make a deep copy
		tree = treeify(deepCopy(lItems))
		debug "TREE", tree

		@tree = tree
		debug "return from getTree()", tree
		return tree

# ---------------------------------------------------------------------------
# Utility function to get a tree from text,
#    given a function to map a string (to anything!)

export treeFromBlock = (block, mapFunc) ->

	class MyTreeMapper extends TreeMapper

		mapNode: (line, level) ->
			assert isString(line), "Mapper.mapNode(): not a string"
			return mapFunc(line, level)

	parser = new MyTreeMapper(block)
	return parser.getTree()

# ---------------------------------------------------------------------------
# Each item must be a sub-array with 3 items: [<level>, <lineNum>, <node>]
# If a predicate is supplied, it must return true for any <node>

export treeify = (lItems, atLevel=0, predicate=undef) ->
	# --- stop when an item of lower level is found, or at end of array

	debug "enter treeify(#{atLevel})"
	debug 'lItems', lItems
	try
		checkTree(lItems, predicate)
		debug "check OK"
	catch err
		croak err, 'lItems', lItems
	lNodes = []
	while (lItems.length > 0) && (lItems[0][0] >= atLevel)
		item = lItems.shift()
		[level, lineNum, node] = item

		if (level != atLevel)
			croak "treeify(): item at level #{level}, should be #{atLevel}",
					"TREE", lItems

		h = {node, lineNum}
		subtree = treeify(lItems, atLevel+1)
		if subtree?
			h.subtree = subtree
		lNodes.push(h)
	if lNodes.length==0
		debug "return undef from treeify()"
		return undef
	else
		debug "return #{lNodes.length} nodes from treeify()", lNodes
		return lNodes

# ---------------------------------------------------------------------------

export checkTree = (lItems, predicate) ->

	# --- Each item should be a sub-array with 3 items:
	#        1. an integer - level
	#        2. an integer - a line number
	#        3. anything, but if predicate is defined, it must return true

	assert isArray(lItems), "treeify(): lItems is not an array"
	for item,i in lItems
		assert isArray(item), "treeify(): lItems[#{i}] is not an array"
		len = item.length
		assert len == 3, "treeify(): item has length #{len}"
		[level, lineNum, node] = item
		assert isInteger(level), "checkTree(): level not an integer"
		assert isInteger(lineNum), "checkTree(): lineNum not an integer"
		if predicate?
			assert predicate(node), "checkTree(): node fails predicate"
	return
