# CodeWalker.coffee

import {strict as assert} from 'assert'
import CoffeeScript from 'coffeescript'

import {undef, say} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {TreeWalker} from '@jdeighan/string-input/tree'

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class CodeWalker extends TreeWalker

	constructor: (text) ->

		ast = CoffeeScript.compile text, {ast: true}
		super ast.program
		@ast = ast.program
		@hImports = {}
		@hSymbols = {}

		# --- subarrays are sets of formal parameters
		#     which are never missing symbols
		@lFormalParams = []

		# --- contains names of variables assigned to
		#     For now, we don't take scope into account
		#     The name of any variable assigned to will
		#        never be considered a missing symbol
		#        (unless it's used before being assigned)
		@lVarNames = []

	# ..........................................................

	isFormalParam: (name) ->

		for subarray in @lFormalParams
			if subarray.includes(name)
				return true
		return false

	# ..........................................................

	isVariableName: (name) ->

		return @lVarNames.includes(name)

	# ..........................................................

	addImport: (name, value={}) ->

		assert name, "addImport: empty name"
		@hImports[name] = value
		return

	# ..........................................................

	addSymbol: (name, value={}) ->

		assert name, "addSymbol: empty name"
		if not @isFormalParam(name) and not @isVariableName(name)
			@hSymbols[name] = value
		return

	# ..........................................................

	visit: (node, level) ->

		debug "tree", node.type
		switch node.type
			when 'ImportDefaultSpecifier'
				@addSymbol node.local.name
			when 'ImportSpecifier'
				@addSymbol node.imported.name
			when 'CallExpression'
				@addSymbol node.callee.name
			when 'ClassDeclaration'
				if node.superClass? && node.superClass.type=='Identifier'
					@addSymbol node.superClass.name
			when 'ReturnStatement'
				if node.argument? && (node.argument.type == 'Identifier')
					@addSymbol node.argument.name
			when 'SwitchStatement'
				if node.discriminant? && (node.discriminant.type == 'Identifier')
					@addSymbol node.discriminant.name
			when 'SwitchCase'
				if node.test? && (node.test.type == 'Identifier')
					@addSymbol node.test.name
			when 'FunctionExpression'
				# --- We need to add to @lFormalParams
				lParams = []
				for hItem in node.params
					if (hItem.type == 'AssignmentPattern')
						{left, right} = hItem
						if left.type == 'Identifier'
							lParams.push left.name
						if right.type == 'Identifier'
							@addSymbol right.name
				@lFormalParams.push lParams
			when 'AssignmentExpression'
				assert node.left?, "assignment expr without left"
				assert node.right?, "assignment expr without right"
				if (node.left.type == 'Identifier')
					@lVarNames.push node.left.name
		return

	# ..........................................................

	endVisit: (node, level) ->
		# --- Called after the node's entire subtree has been walked

		if (node.type == 'FunctionExpression')
			@lFormalParams.pop()

		debug "untree"
		return

	# ..........................................................

	getSubTrees: (node) ->

		lSubTrees = []
		add = (subtrees...) -> lSubTrees.push subtrees...

		switch node.type
			when 'Program','BlockStatement', \
					'ClassDeclaration','ClassBody','ClassMethod'
				add node.body
			when 'ExpressionStatement'
				add node.expression
			when 'IfStatement'
				add node.test, node.consequent
			when 'BinaryExpression','AssignmentExpression'
				add node.left, node.right
			when 'ExpressionStatement'
				add node.expression
			when 'For'
				add node.body, node.source
			when 'SwitchStatement'
				add node.cases
			when 'SwitchCase'
				add node.test, node.consequent
			when 'FunctionExpression'
				add node.params, node.body
		return lSubTrees

	# ..........................................................

	getMissingSymbols: () ->

		@hImports = {}
		@hSymbols = {}
		@walk()
		for key in Object.keys(@hImports)
			if @hSymbols[key]?
				delete @hSymbols[key]
		return @hSymbols
