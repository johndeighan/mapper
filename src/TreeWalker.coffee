# TreeWalker.coffee

import {
	assert, undef, pass, croak, isArray, isHash, isArrayOfHashes,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {indented} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class TreeWalker

	constructor: (@root) ->
		# --- root can be a hash or array of hashes

		pass

	# ..........................................................

	walk: () ->

		debug "enter TreeWalker.walk"
		if isHash(@root)
			debug "walking node"
			@walkNode @root, 0
		else if isArrayOfHashes(@root)
			debug "walking array"
			@walkNodes @root, 0
		else
			croak "TreeWalker: Invalid root", 'ROOT', @root
		debug "return from TreeWalker.walk"
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
					croak "Invalid subtree", 'SUBTREE', subtree
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

export class ASTWalker extends TreeWalker

	constructor: (ast) ->

		super ast.program
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

	visit: (node, level) ->


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

		debug "enter CodeWalker.getNeededSymbols()"

		@lImportedSymbols = []  # filled in during walking
		@lUsedSymbols = []      # filled in during walking

		debug "walking"
		@walk()
		debug "done walking"

		lNeededSymbols = []
		for name in @lUsedSymbols
			if ! @lImportedSymbols.includes(name)
				lNeededSymbols.push(name)

		debug "return from CodeWalker.getNeededSymbols()"
		return {
			lImported: @lImportedSymbols,
			lUsed:     @lUsedSymbols,
			lNeeded:   lNeededSymbols,
			}

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
			if (! @excludeKey(key))
				newnode[key] = node[key]
		return JSON.stringify(newnode)
