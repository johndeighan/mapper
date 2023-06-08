# cielo.coffee

import {
	undef, defined, OL, className, getOptions,
	isEmpty, nonEmpty, isString, isHash, isArray, toBlock,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {slurp, barf} from '@jdeighan/base-utils/fs'
import {
	indentLevel, indented, isUndented, splitLine,
	} from '@jdeighan/coffee-utils/indent'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	withExt, newerDestFileExists, shortenPath,
	} from '@jdeighan/coffee-utils/fs'

import {TreeMapper} from '@jdeighan/mapper/tree'
import {coffeeCodeToJS, coffeeExprToJS} from '@jdeighan/mapper/coffee'
import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'
import {map, Mapper} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export cieloToJSCode = (hInput) ->

	dbgEnter 'cieloToJSCode', hInput
	mapper = new CieloToJSCodeMapper(hInput)
	jsCode = mapper.getBlock()
	lNeededSymbols = mapper.lNeededSymbols
	if defined(lNeededSymbols)
		# --- Prepend needed imports
		fullpath = mapper.hSourceInfo.fullpath
		{lImports, lNotFound} = buildImportList(lNeededSymbols, fullpath)
		dbg "lImports", lImports
		dbg 'lNotFound', lNotFound

		# --- append ';' to import statements
		lImports = for stmt in lImports
			stmt + ';'

		# --- joinBlocks() flattens all its arguments to array of strings
		jsCode = joinBlocks(lImports, jsCode)

	dbgReturn 'cieloToJSCode', jsCode
	return jsCode

# ---------------------------------------------------------------------------

export cieloToJSExpr = (hInput) ->

	dbgEnter 'cieloToJSExpr', hInput
	mapper = new CieloToJSExprMapper(hInput)
	jsExpr = mapper.getBlock()

	# --- mapper possibly has key lNeededSymbols
	result = {
		code: jsExpr
		lNeededSymbols: mapper.lNeededSymbols
		}
	dbgReturn 'cieloToJSExpr', result
	return result

# ---------------------------------------------------------------------------

export class CieloMapper extends TreeMapper

	mapComment: (hNode) ->

		# --- Retain comments
		return hNode.str

	# ..........................................................

	visitCmd: (hNode) ->

		dbgEnter "CieloMapper.visitCmd", hNode
		{uobj, srcLevel, level} = hNode
		{cmd, argstr} = uobj

		switch cmd
			when 'reactive'
				# --- This allows either a statement on the same line
				#     OR following indented text
				#     but not both
				code = @containedText(hNode, argstr)
				dbg 'code', code
				if (code == argstr)
					result = toBlock([
						indented('# |||| $:', level)
						indented(code, level)
						])
				else
					result = toBlock([
						indented('# |||| $: {', level)
						indented(code, level)
						indented('# |||| }', level)
						])
				dbgReturn "CieloMapper.visitCmd", result
				return result

			else
				super(hNode)

		dbgReturn "CieloMapper.visitCmd", undef
		return undef

	# ..........................................................

	containedText: (hNode, inlineText) ->
		# --- has side effect of fetching all indented text

		dbgEnter "CieloMapper.containedText", hNode, inlineText
		{srcLevel} = hNode

		block = @fetchBlockAtLevel(srcLevel+1)

		dbg "inline text", inlineText
		dbg "indented text", block

		if nonEmpty(block)
			assert isEmpty(inlineText),
				"node #{OL(hNode)} has both inline text and indented text"
			result = block
		else if isEmpty(inlineText)
			result = ''
		else
			result = inlineText
		dbgReturn "CieloMapper.containedText", result
		return result

# ---------------------------------------------------------------------------

export class CieloToJSCodeMapper extends CieloMapper

	finalizeBlock: (coffeeCode) ->

		dbgEnter "CieloToJSCodeMapper.finalizeBlock", coffeeCode
		try
			fullpath = @hSourceInfo.fullpath
			jsCode = coffeeCodeToJS(coffeeCode)
		catch err
			croak err, "Original Code", coffeeCode

		lNeededSymbols = getNeededSymbols(coffeeCode)
		if nonEmpty(lNeededSymbols)
			@lNeededSymbols = lNeededSymbols
		dbgReturn "CieloToJSCodeMapper.finalizeBlock", jsCode
		return jsCode

# ---------------------------------------------------------------------------

export class CieloToJSExprMapper extends CieloMapper

	finalizeBlock: (coffeeExpr) ->

		dbgEnter "CieloToJSExprMapper.finalizeBlock", coffeeExpr
		try
			fullpath = @hSourceInfo.fullpath
			jsExpr = coffeeExprToJS(coffeeExpr)
		catch err
			croak err, "Original Expr", coffeeExpr

		lNeededSymbols = getNeededSymbols(coffeeExpr)
		if nonEmpty(lNeededSymbols)
			@lNeededSymbols = lNeededSymbols

		dbgReturn "CieloToJSExprMapper.finalizeBlock", jsExpr
		return jsExpr

# ---------------------------------------------------------------------------

export cieloFileToJS = (srcPath, destPath=undef, hOptions={}) ->
	# --- cielo => js
	#     Valid Options:
	#        saveAST
	#        force
	#        premapper
	#        postmapper

	if notdefined(destPath)
		destPath = withExt(srcPath, '.js')
	{force, saveAST} = getOptions(hOptions)
	if force || ! newerDestFileExists(srcPath, destPath)
		cieloCode = slurp(srcPath)
		if saveAST
			dumpfile = withExt(srcPath, '.ast')
			lNeeded = getNeededSymbols(cieloCode, {dumpfile})
			if (lNeeded == undef) || (lNeeded.length == 0)
				dbg "NO NEEDED SYMBOLS in #{shortenPath(destPath)}:"
			else
				n = lNeeded.length
				word = if (n==1) then'SYMBOL' else 'SYMBOLS'
				dbg "#{n} NEEDED #{word} in #{shortenPath(destPath)}:"
				for sym in lNeeded
					dbg "   - #{sym}"
		jsCode = cieloToJSCode({content: cieloCode, source: srcPath})
		barf jsCode, destPath
	return
