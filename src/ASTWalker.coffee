# ASTWalker.coffee

import {assert, croak, debug, LOG, LOGVALUE} from '@jdeighan/exceptions'
import {fromTAML, toTAML} from '@jdeighan/exceptions/taml'
import {
	undef, pass, defined, notdefined, OL, words, deepCopy, getOptions,
	isString, nonEmpty, isArray, isHash, isArrayOfHashes, removeKeys,
	} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {toBlock} from '@jdeighan/coffee-utils/block'

import {coffeeCodeToAST} from '@jdeighan/mapper/coffee'
import {Context} from '@jdeighan/mapper/context'

hAllHandlers = fromTAML('''
	---
	File:
		lWalkTrees:
			- program
	Program:
		lWalkTrees:
			- body
	ArrayExpression:
		lWalkTrees:
			- elements
	AssignmentExpression:
		lDefined:
			- left
		lUsed:
			- right
	AssignmentPattern:
		lDefined:
			- left
		lWalkTrees:
			- right
	BinaryExpression:
		lUsed:
			- left
			- right
	BlockStatement:
		lWalkTrees:
			- body
	ClassBody:
		lWalkTrees:
			- body
	ClassDeclaration:
		lWalkTrees:
			- body
	ClassMethod:
		lWalkTrees:
			- body
	ExpressionStatement:
		lWalkTrees:
			- expression
	IfStatement:
		lWalkTrees:
			- test
			- consequent
			- alternate
	LogicalExpression:
		lWalkTrees:
			- left
			- right
	SpreadElement:
		lWalkTrees:
			- argument
	SwitchStatement:
		lWalkTrees:
			- cases
	SwitchCase:
		lWalkTrees:
			- test
			- consequent
	TemplateLiteral:
		lWalkTrees:
			- expressions
	TryStatement:
		lWalkTrees:
			- block
			- handler
			- finalizer
	WhileStatement:
		lWalkTrees:
			- test
			- body
	''')

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class ASTWalker

	constructor: (from) ->

		debug "enter ASTWalker()"

		if isString(from)
			@ast = coffeeCodeToAST(from)
		else
			@ast = from

		# --- @ast can be a hash or array of hashes
		if isHash(@ast)
			debug "tree was hash - constructing list from it"
			@ast = [@ast]
		assert isArrayOfHashes(@ast), "not array of hashes: #{OL(@ast)}"

		# --- Info to accumulate
		@lImportedSymbols = []
		@lExportedSymbols = []
		@lUsedSymbols     = []
		@lMissingSymbols  = []

		@context = new Context()
		debug "return from ASTWalker()"

	# ..........................................................

	addImport: (name, lib) ->

		debug "enter addImport('#{name}')"
		@check name
		if @lImportedSymbols.includes(name)
			LOG "Duplicate import: #{name}"
		else
			@lImportedSymbols.push(name)
		@context.addGlobal(name)
		debug "return from addImport()"
		return

	# ..........................................................

	addExport: (name, lib) ->

		debug "enter addExport('#{name}')"
		@check name
		if @lExportedSymbols.includes(name)
			LOG "Duplicate export: #{name}"
		else
			@lExportedSymbols.push(name)
		debug "return from addExport()"
		return

	# ..........................................................

	addDefined: (name, value={}) ->

		debug "enter addDefined('#{name}')"
		@check name
		if @context.atGlobalLevel()
			@context.addGlobal name
		else
			@context.add name
		debug "return from addDefined()"
		return

	# ..........................................................

	addUsed: (name, value={}) ->

		debug "enter addUsed('#{name}')"
		@check name
		if ! @lUsedSymbols.includes(name)
			@lUsedSymbols.push(name)
		if ! @context.has(name) \
				&& ! @lMissingSymbols.includes(name)
			@lMissingSymbols.push name
		debug "return from addUsed()"
		return

	# ..........................................................

	walk: (options=undef) ->
		# --- Valid options:
		#        asText

		debug "enter walk()"
		for node in @ast
			@visit node, 0

		# --- get symbols to return

		# --- not needed if:
		#        1. in lImported
		#        2. not in lUsedSymbols
		#        3. not in lExportedSymbols
		lNotNeeded = []
		for name in @lImportedSymbols
			if ! @lUsedSymbols.includes(name) && ! @lExportedSymbols.includes(name)
				lNotNeeded.push name

		hInfo = {
			lImported: @lImportedSymbols,
			lExported: @lExportedSymbols,
			lUsed:     @lUsedSymbols,
			lMissing:  @lMissingSymbols,
			lNotNeeded
			}
		{asText} = getOptions(options)
		if asText
			lLines = []
			for label in words('lImported lExported lMissing')
				if nonEmpty(hInfo[label])
					lLines.push "#{label}: #{hInfo[label].join(' ')}"
			result = toBlock(lLines)
		else
			result = hInfo

		debug "return from walk()", result
		return result

	# ..........................................................

	walkTree: (tree, level=0) ->

		debug "enter walkTree()"
		if isArray(tree)
			for node in tree
				@walkTree node, level
		else
			assert isHash(tree, ['type']), "bad tree: #{OL(tree)}"
			@visit tree, level
		debug "return from walkTree()"
		return

	# ..........................................................
	# --- return true if handled, false if not

	handle: (node, level) ->

		debug "enter handle()"
		{type} = node
		debug "type is #{OL(type)}"
		hHandlers = hAllHandlers[type]
		if notdefined(hHandlers)
			debug "return false from handle()"
			return false

		{lWalkTrees, lDefined, lUsed} = hHandlers
		if defined(lDefined)
			debug "has lDefined"
			for key in lDefined
				subnode = node[key]
				if subnode.type == 'Identifier'
					@addDefined subnode.name
				else
					@walkTree subnode, level+1

		if defined(lUsed)
			debug "has lUsed"
			for key in lUsed
				subnode = node[key]
				if subnode.type == 'Identifier'
					@addUsed subnode.name
				else
					@walkTree subnode, level+1

		if defined(lWalkTrees)
			debug "has lWalkTrees"
			for key in lWalkTrees
				subnode = node[key]
				if isArray(subnode)
					for tree in subnode
						@walkTree tree, level+1
				else if defined(subnode)
					@walkTree subnode, level+1

		debug "return true from handle()"
		return true

	# ..........................................................

	visit: (node, level) ->

		debug "enter ASTWalker.visit(type=#{node.type})"
		assert defined(node), "node is undef"

		if @handle(node, level)
			debug "return from ASTWalker.visit()"
			return

		switch node.type

			when 'CallExpression'
				{callee} = node
				if (callee.type == 'Identifier')
					@addUsed callee.name
				else
					@walkTree callee, level+1
				for arg in node.arguments
					if (arg.type == 'Identifier')
						@addUsed arg.name
					else
						@walkTree arg, level+1

			when 'CatchClause'
				param = node.param
				if defined(param) && (param.type=='Identifier')
					@addDefined param.name
				@walkTree node.body, level+1

			when 'ExportNamedDeclaration'
				{specifiers, declaration} = node
				if defined(declaration)
					{type, id, left} = declaration
					if (type == 'ClassDeclaration')
						@addExport id.name
					else if (type == 'AssignmentExpression')
						if (left.type == 'Identifier')
							@addExport left.name
					@walkTree declaration, level+1

				if defined(specifiers)
					for spec in specifiers
						name = spec.exported.name
						@addExport name

			when 'For'
				if defined(node.name) && (node.name.type=='Identifier')
					@addDefined node.name.name

				if defined(node.index) && (node.name.type=='Identifier')
					@addDefined node.index.name
				@walkTree node.source, level+1
				@walkTree node.body, level+1

			when 'FunctionExpression','ArrowFunctionExpression'
				lParmNames = []
				if defined(node.params)
					for parm in node.params
						switch parm.type
							when 'Identifier'
								lParmNames.push parm.name
							when 'AssignmentPattern'
								{left, right} = parm
								if left.type == 'Identifier'
									lParmNames.push left.name
								if right.type == 'Identifier'
									@addUsed right.name
								else
									@walkTree right, level+1
				@context.beginScope '<unknown>', lParmNames
				@walkTree node.params, level+1
				@walkTree node.body, level+1
				@context.endScope()

			when 'ImportDeclaration'
				{specifiers, source, importKind} = node
				if (importKind == 'value') && (source.type == 'StringLiteral')
					lib = source.value     # e.g. '@jdeighan/coffee-utils'

					for hSpec in specifiers
						{type, imported, local, importKind} = hSpec
						if (type == 'ImportSpecifier') \
								&& defined(imported) \
								&& (imported.type == 'Identifier')
							@addImport imported.name, lib

			when 'NewExpression'
				if node.callee.type == 'Identifier'
					@addUsed node.callee.name
				for arg in node.arguments
					if arg.type == 'Identifier'
						@addUsed arg.name
					else
						@walkSubtree arg

			when 'MemberExpression'
				{object} = node
				if object.type == 'Identifier'
					@addUsed object.name
				@walkTree object

			when 'ReturnStatement'
				{argument} = node
				if defined(argument)
					if (argument.type == 'Identifier')
						@addUsed argument.name
					else
						@walkTree argument

		debug "return from ASTWalker.visit()"
		return

	# ..........................................................

	check: (name) ->

		assert nonEmpty(name), "empty name"
		return

	# ..........................................................

	getBasicAST: (asTAML=true) ->

		ast = deepCopy @ast
		lToRemove = words(
			'start end extra declarations loc range tokens comments',
			'assertions implicit optional async generator id hasIndentedBody'
			)
		lSortBy = words(
			"type params body left right"
			)
		removeKeys(ast, lToRemove)

		if asTAML
			return toTAML(ast, {sortKeys: lSortBy})
		else
			return ast
