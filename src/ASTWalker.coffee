# ASTWalker.coffee

import {
	assert, undef, pass, croak, isArray, isHash, isArrayOfHashes,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {indented} from '@jdeighan/coffee-utils/indent'

import {isBuiltin} from '@jdeighan/mapper/builtins'

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

class TreeWalker

	constructor: (@tree, hStdKeys={}) ->
		debug "enter TreeWalker()", hStdKeys

		# --- tree can be a hash or array of hashes
		if isHash(@tree)
			debug "tree was hash - constructing list from it"
			@tree = [@tree]
		assert isArrayOfHashes(@tree), "new TreeWalker: Bad tree"

		# --- @hStdKeys allows you to provide an alternate name for 'subtree'
		#     Ditto for 'node', but if the 'node' key exists, but is
		#        set to undef, the tree is assumed to NOT use user nodes
		@hStdKeys = {}

		if hStdKeys.subtree?
			assert hStdKeys.subtree, "empty subtree key"
			@hStdKeys.subtree = hStdKeys.subtree
		else
			@hStdKeys.subtree = 'subtree'

		if hStdKeys.node?            # --- if set to undef, leave it alone
			@hStdKeys.node = hStdKeys.node
		else
			@hStdKeys.node = 'node'

		debug "return from TreeWalker()", @hStdKeys

	# ..........................................................
	# --- Called after walk() completes
	#     Override to have walk() return some result

	getResult: () ->

		return undef

	# ..........................................................

	walk: () ->

		debug "enter TreeWalker.walk()"
		@walkNodes @tree, 0
		result = @getResult()
		debug "return from TreeWalker.walk()", result
		return result

	# ..........................................................

	walkNodes: (lNodes, level) ->

		debug "enter walkNodes()", lNodes
		for node in lNodes
			@walkNode node, level
		debug "return from walkNodes()"
		return

	# ..........................................................

	walkSubTrees: (lSubTrees, level) ->

		if !lSubTrees? || (lSubTrees.length==0)
			return
		for subtree in lSubTrees
			if subtree?
				if isArray(subtree)
					@walkNodes subtree, level
				else if isHash(subtree)
					@walkNode subtree, level
				else
					croak "Invalid subtree", 'SUBTREE', subtree
		return

	# ..........................................................

	walkNode: (superNode, level) ->

		debug "enter walkNode()"

		key = @hStdKeys.node
		subkey = @hStdKeys.subtree
		debug "KEYS: '#{key}', '#{subkey}'"

		node = superNode
		if key && superNode[key]?
			debug "found node under key '#{key}'"
			node = superNode[key]

		# --- give visit() method chance to provide list of subtrees
		lSubTrees = @visit node, superNode, level

		if lSubTrees?
			debug "visit() returned subtrees", lSubTrees
			@walkSubTrees lSubTrees, level+1
		else
			@walkSubTrees superNode[subkey], level+1
		@endVisit node, superNode, level
		debug "return from walkNode()"
		return

	# ..........................................................
	# --- return lSubTrees, if any

	visit: (node, hInfo, level) ->

		debug "enter visit() - std"
		# --- automatically visit subtree if it exists
		debug "return from visit() - std"
		return undef

	# ..........................................................
	# --- called after all subtrees have been visited

	endVisit: (node, hInfo, level) ->

		return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class ASTWalker extends TreeWalker

	constructor: (ast) ->

		super ast.program, {subtree: 'body', node: undef}
		@ast = ast.program
		@lImportedSymbols = []
		@lUsedSymbols = []

		# --- subarrays start out as list of formal parameters
		#     to which are added locally assigned variables
		@lLocalSymbols = [[]]

	# ..........................................................

	isLocalSymbol: (name) ->

		for subarray in @lLocalSymbols
			if subarray.includes(name)
				return true
		return false

	# ..........................................................

	addImport: (name, lib) ->

		assert name, "addImport: empty name"
		if @lImportedSymbols.includes(name)
			croak "Duplicate import: #{name}"
		else
			@lImportedSymbols.push(name)
		return

	# ..........................................................

	addUsedSymbol: (name, value={}) ->

		assert name, "addUsedSymbol(): empty name"
		if ! @isLocalSymbol(name) && ! @lUsedSymbols.includes(name)
			@lUsedSymbols.push(name)
		return

	# ..........................................................

	addLocalSymbol: (name) ->

		assert @lLocalSymbols.length > 0, "no lLocalSymbols"
		lSymbols = @lLocalSymbols[@lLocalSymbols.length - 1]
		lSymbols.push name
		return

	# ..........................................................

	visit: (node, hInfo, level) ->


		# --- add to local vars & formal params, where appropriate
		switch node.type

			when 'Identifier'
				# --- Identifiers that are not local vars or formal params
				#     are symbols that should be imported

				name = node.name
				if ! @isLocalSymbol(name)
					@addUsedSymbol name
				return

			when 'ImportDeclaration'
				{specifiers, source, importKind} = node
				if (importKind == 'value') && (source.type == 'StringLiteral')
					lib = source.value     # e.g. '@jdeighan/coffee-utils'

					for hSpec in specifiers
						{type, imported, local, importKind} = hSpec
						if (type == 'ImportSpecifier') \
								&& imported? \
								&& (imported.type == 'Identifier')
							@addImport imported.name, lib
				return

			when 'CatchClause'
				param = node.param
				if param? && param.type=='Identifier'
					@lLocalSymbols.push param.name

			when 'FunctionExpression'
				lNames = []
				for parm in node.params
					if parm.type == 'Identifier'
						lNames.push parm.name
				@lLocalSymbols.push lNames

			when 'For'
				lNames = []
				if node.name? && (node.name.type=='Identifier')
					lNames.push node.name.name

				if node.index? && (node.name.type=='Identifier')
					lNames.push node.index.name

				@lLocalSymbols.push lNames

			when 'AssignmentExpression'
				if node.left.type == 'Identifier'
					@addLocalSymbol node.left.name

			when 'AssignmentPattern'
				if node.left.type == 'Identifier'
					@addLocalSymbol node.left.name

		# --- Build and return array of subtrees

		lSubTrees = []
		add = (subtrees...) -> lSubTrees.push subtrees...

		switch node.type
			when 'AssignmentExpression'
				add node.left, node.right
			when 'AssignmentPattern'
				add node.left, node.right
			when 'BinaryExpression'
				add node.left, node.right
			when 'BlockStatement'
				add node.body
			when 'CallExpression'
				add node.callee, node.arguments
			when 'CatchClause'
				add node.body
			when 'ClassDeclaration'
				add node.body
			when 'ClassBody'
				add node.body
			when 'ClassMethod'
				add node.body
			when 'ExpressionStatement'
				add node.expression
			when 'For'
				add node.body, node.source
			when 'FunctionExpression'
				add node.params, node.body
			when 'IfStatement'
				add node.test, node.consequent
			when 'MemberExpression'
				add node.object
			when 'Program'
				add node.body
			when 'SwitchCase'
				add node.test, node.consequent
			when 'SwitchStatement'
				add node.cases
			when 'TryStatement'
				add node.block, node.handler, node.finalizer
			when 'WhileStatement'
				add node.test, node.body
		return lSubTrees

	# ..........................................................

	endVisit: (node, level) ->
		# --- Called after the node's entire subtree has been walked

		switch node.type
			when 'FunctionExpression','For', 'CatchClause'
				@lLocalSymbols.pop()

		return

	# ..........................................................

	getSymbols: () ->

		debug "enter CodeWalker.getSymbols()"

		@lImportedSymbols = []  # filled in during walking
		@lUsedSymbols = []      # filled in during walking

		debug "walking"
		@walk()
		debug "done walking"

		lNeededSymbols = []
		for name in @lUsedSymbols
			if ! @lImportedSymbols.includes(name) && ! isBuiltin(name)
				lNeededSymbols.push(name)

		hResult = {
			lImported: @lImportedSymbols,
			lUsed:     @lUsedSymbols,
			lNeeded:   lNeededSymbols,
			}
		debug "return from CodeWalker.getSymbols()", hResult
		return hResult

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class TreeStringifier extends TreeWalker

	constructor: (tree, hStdKeys={}) ->

		debug "enter TreeStringifier()", tree
		super(tree, hStdKeys)      # sets @tree
		@lLines = []
		debug "return from TreeStringifier()"

	# ..........................................................

	visit: (node, hInfo, level) ->

		assert node?, "TreeStringifier.visit(): empty node"
		debug "enter TreeStringifier.visit()"
		str = indented(@stringify(node), level)
		debug "stringified: '#{str}'"
		@lLines.push str
		debug "return from TreeStringifier.visit()"
		return undef

	# ..........................................................

	get: () ->

		debug "enter TreeStringifier.get()"
		@walk()
		result = @lLines.join('\n')
		debug "return from TreeStringifier.get()"
		return result

	# ..........................................................

	excludeKey: (key) ->

		return (key == @hStdKeys.subtree)

	# ..........................................................
	# --- override this

	stringify: (node) ->

		assert isHash(node),
				"TreeStringifier.stringify(): node '#{node}' is not a hash"
		newnode = {}
		for key,value of node
			if (! @excludeKey(key))
				newnode[key] = node[key]
		return JSON.stringify(newnode)

