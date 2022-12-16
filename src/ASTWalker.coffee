# ASTWalker.coffee

import {assert, croak, LOG, LOGVALUE} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {fromTAML, toTAML} from '@jdeighan/base-utils/taml'
import {
	undef, pass, defined, notdefined, OL, words, deepCopy, getOptions,
	isString, nonEmpty, isArray, isHash, isArrayOfHashes, removeKeys,
	} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {toBlock} from '@jdeighan/coffee-utils/block'
import {barf} from '@jdeighan/coffee-utils/fs'

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

		dbgEnter "ASTWalker", from

		if isString(from)
			@ast = coffeeCodeToAST(from)
		else
			@ast = from

		# --- @ast can be a hash or array of hashes
		if isHash(@ast)
			dbg "tree was hash - constructing list from it"
			@ast = [@ast]
		assert isArrayOfHashes(@ast), "not array of hashes: #{OL(@ast)}"

		# --- Info to accumulate
		@lImportedSymbols = []
		@lExportedSymbols = []
		@lUsedSymbols     = []
		@lMissingSymbols  = []

		@context = new Context()
		dbgReturn "ASTWalker"

	# ..........................................................

	addImport: (name, lib) ->

		dbgEnter "addImport", name, lib
		@check name
		if @lImportedSymbols.includes(name)
			LOG "Duplicate import: #{name}"
		else
			@lImportedSymbols.push(name)
		@context.addGlobal(name)
		dbgReturn "addImport"
		return

	# ..........................................................

	addExport: (name, lib) ->

		dbgEnter "addExport", name
		@check name
		if @lExportedSymbols.includes(name)
			LOG "Duplicate export: #{name}"
		else
			@lExportedSymbols.push(name)
		dbgReturn "addExport"
		return

	# ..........................................................

	addDefined: (name, value={}) ->

		dbgEnter "addDefined", name
		@check name
		if @context.atGlobalLevel()
			@context.addGlobal name
		else
			@context.add name
		dbgReturn "addDefined"
		return

	# ..........................................................

	addUsed: (name, value={}) ->

		dbgEnter "addUsed", name
		@check name
		if ! @lUsedSymbols.includes(name)
			@lUsedSymbols.push(name)
		if ! @context.has(name) \
				&& ! @lMissingSymbols.includes(name)
			@lMissingSymbols.push name
		dbgReturn "addUsed"
		return

	# ..........................................................

	walk: (options=undef) ->
		# --- Valid options:
		#        asText

		dbgEnter "walk"
		for node in @ast
			@visit node, 0

		# --- get symbols to return

		# --- not needed if:
		#        1. in lImported
		#        2. not in lUsedSymbols
		#        3. not in lExportedSymbols
		lNotNeeded = []
		for name in @lImportedSymbols
			if ! @lUsedSymbols.includes(name) \
					&& ! @lExportedSymbols.includes(name)
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

		dbgReturn "walk", result
		return result

	# ..........................................................

	walkTree: (tree, level=0) ->

		dbgEnter "walkTree"
		if isArray(tree)
			for node in tree
				@walkTree node, level
		else
			assert isHash(tree, ['type']), "bad tree: #{OL(tree)}"
			@visit tree, level
		dbgReturn "walkTree"
		return

	# ..........................................................
	# --- return true if handled, false if not

	handle: (node, level) ->

		dbgEnter "handle"
		{type} = node
		dbg "type is #{OL(type)}"
		hHandlers = hAllHandlers[type]
		if notdefined(hHandlers)
			dbgReturn "handle", false
			return false

		{lWalkTrees, lDefined, lUsed} = hHandlers
		if defined(lDefined)
			dbg "has lDefined"
			for key in lDefined
				subnode = node[key]
				if subnode.type == 'Identifier'
					@addDefined subnode.name
				else
					@walkTree subnode, level+1

		if defined(lUsed)
			dbg "has lUsed"
			for key in lUsed
				subnode = node[key]
				if subnode.type == 'Identifier'
					@addUsed subnode.name
				else
					@walkTree subnode, level+1

		if defined(lWalkTrees)
			dbg "has lWalkTrees"
			for key in lWalkTrees
				subnode = node[key]
				if isArray(subnode)
					for tree in subnode
						@walkTree tree, level+1
				else if defined(subnode)
					@walkTree subnode, level+1

		dbgReturn "handle", true
		return true

	# ..........................................................

	visit: (node, level) ->

		dbgEnter "ASTWalker.visit", node, level
		assert defined(node), "node is undef"

		if @handle(node, level)
			dbgReturn "ASTWalker.visit"
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
#				console.dir node
				{specifiers, declaration} = node
				if defined(declaration)
					{type, id, left, body} = declaration
					switch type
						when 'ClassDeclaration'
							if defined(id)
								@addExport id.name
							else if defined(body)
								@walkTree node.body, level+1
						when 'AssignmentExpression'
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

		dbgReturn "ASTWalker.visit"
		return

	# ..........................................................

	check: (name) ->

		assert nonEmpty(name), "empty name"
		return

	# ..........................................................

	barfAST: (filePath, hOptions={}) ->

		{full} = getOptions(hOptions)
		lSortBy = words("type params body left right")
		if full
			barf filePath, toTAML(@ast, {sortKeys: lSortBy})
		else
			astCopy = deepCopy @ast
			removeKeys astCopy, words(
				'start end extra declarations loc range tokens comments',
				'assertions implicit optional async generato hasIndentedBody'
				)
			barf filePath, toTAML(astCopy, {sortKeys: lSortBy})
