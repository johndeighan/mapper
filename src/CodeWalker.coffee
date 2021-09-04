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
		@hMissingSymbols = {}

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

	addImport: (name, value={}) ->

		assert name, "addImport: empty name"
		@hImports[name] = value
		return

	# ..........................................................

	addMissingSymbol: (name, value={}) ->

		assert name, "addMissingSymbol: empty name"
		if not @isLocalSymbol(name)
			@hMissingSymbols[name] = value
		return

	# ..........................................................

	addLocalSymbol: (name) ->

		assert @lLocalSymbols.length > 0, "no lLocalSymbols"
		lSymbols = @lLocalSymbols[@lLocalSymbols.length - 1]
		lSymbols.push name
		return

	# ..........................................................

	visit: (node, level) ->

		# --- Identifiers that are not local vars or formal params
		#     are symbols that should be imported

		if (node.type == 'Identifier')
			name = node.name
			if not @isLocalSymbol(name)
				@addMissingSymbol name
			return

		# --- add to local vars & formal params, where appropriate
		switch node.type

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
		return lSubTrees

	# ..........................................................

	endVisit: (node, level) ->
		# --- Called after the node's entire subtree has been walked

		switch node.type
			when 'FunctionExpression','For'
				@lLocalSymbols.pop()

		debug "untree"
		return

	# ..........................................................

	getMissingSymbols: () ->

		@hImports = {}
		@hMissingSymbols = {}
		@walk()
		for key in Object.keys(@hImports)
			if @hMissingSymbols[key]?
				delete @hMissingSymbols[key]
		return @hMissingSymbols
