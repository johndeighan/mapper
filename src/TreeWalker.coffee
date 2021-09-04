# TreeWalker.coffee

import {strict as assert} from 'assert'
import CoffeeScript from 'coffeescript'

import {
	say, pass, undef, error, warn,
	isString, isArray, isHash, isArrayOfHashes, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {debug, debugging} from '@jdeighan/coffee-utils/debug'
import {indented} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------

export class TreeWalker

	constructor: (@root) ->
		# --- root can be a hash or array of hashes

		pass

	# ..........................................................

	walk: () ->

		if isHash(@root)
			@walkNode @root, 0
		else if isArrayOfHashes(@root)
			@walkNodes @root, 0
		else
			error "TreeWalker: Invalid root"
		return

	# ..........................................................

	walkSubTrees: (lSubTrees, level) ->

		for subtree in lSubTrees
			if subtree?
				if isArray(subtree)
					@walkNodes subtree, level
				else if isHash(subtree)
					@walkNode subtree, level
				else
					error "Invalid subtree"
		return

	# ..........................................................

	walkNode: (node, level) ->

		lSubTrees = @visit node, level
		if lSubTrees
			@walkSubTrees lSubTrees, level+1
		@endVisit node, level

	# ..........................................................

	walkNodes: (lNodes, level=0) ->

		for node in lNodes
			@walkNode node, level
		return

	# ..........................................................
	# --- return lSubTrees, if any

	visit: (node, level) ->

		return node.body  # it's handled ok if node.body is undef

	# ..........................................................
	# --- called after all subtrees have been visited

	endVisit: (node, level) ->

		return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class TreeStringifier extends TreeWalker

	constructor: (tree) ->

		super(tree)      # sets @tree
		@lLines = []

	# ..........................................................

	visit: (node, level) ->

		assert node?, "TreeStringifier.visit(): empty node"
		debug "enter visit()"
		str = indented(@stringify(node), level)
		debug "stringified: '#{str}'"
		@lLines.push str
		if node.body
			debug "return from visit() - has subtree 'body'"
			return node.body
		else
			debug "return from visit()"
			return undef

	# ..........................................................

	get: () ->

		@walk()
		return @lLines.join('\n')

	# ..........................................................

	excludeKey: (key) ->

		return (key=='body')

	# ..........................................................
	# --- override this

	stringify: (node) ->

		assert isHash(node),
				"TreeStringifier.stringify(): node '#{node}' is not a hash"
		newnode = {}
		for key,value of node
			if (not @excludeKey(key))
				newnode[key] = node[key]
		return JSON.stringify(newnode)
