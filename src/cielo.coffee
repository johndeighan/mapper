# cielo.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {
	undef, defined, OL, replaceVars, className,
	isEmpty, nonEmpty, isString, isHash, isArray,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, indented, isUndented, splitLine,
	} from '@jdeighan/coffee-utils/indent'
import {
	joinBlocks, arrayToBlock, blockToArray,
	} from '@jdeighan/coffee-utils/block'
import {
	withExt, slurp, barf, newerDestFileExists, shortenPath,
	} from '@jdeighan/coffee-utils/fs'

import {TreeMapper} from '@jdeighan/mapper/tree'
import {coffeeCodeToJS} from '@jdeighan/mapper/coffee'
import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'
import {map, Mapper} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export class CieloMapper extends TreeMapper

	mapComment: (hNode) ->

		# --- Retain comments
		{str, level} = hNode
		return indented(str, level, @oneIndent)

	# ..........................................................

	visitCmd: (hNode) ->

		dbgEnter "CieloMapper.visitCmd", hNode
		{uobj, srcLevel, level, lineNum} = hNode
		{cmd, argstr} = uobj

		switch cmd
			when 'reactive'
				# --- This allows either a statement on the same line
				#     OR following indented text
				#     but not both
				code = @containedText(hNode, argstr)
				dbg 'code', code
				if (code == argstr)
					result = arrayToBlock([
						indented('# |||| $:', level)
						indented(code, level)
						])
				else
					result = arrayToBlock([
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

		lLines = []
		while defined(hNext = @peek()) \
				&& (hNext.isEmptyLine() || (hNext.srcLevel > srcLevel))
			lLines.push @fetch().getLine()
		indentedText = undented(toBlock(lLines))

		dbg "inline text", inlineText
		dbg "indentedText", indentedText

		if nonEmpty(indentedText)
			assert isEmpty(inlineText),
				"node #{OL(hNode)} has both inline text and indented text"
			result = indentedText
		else if isEmpty(inlineText)
			result = ''
		else
			result = inlineText
		dbgReturn "CieloMapper.containedText", result
		return result

# ---------------------------------------------------------------------------

export class CieloToJSMapper extends CieloMapper

	finalizeBlock: (coffeeCode) ->

		dbgEnter "CieloToJSMapper.finalizeBlock", coffeeCode
		lNeededSymbols = getNeededSymbols(coffeeCode)
		dbg "#{lNeededSymbols.length} needed symbols", lNeededSymbols
		try
			jsCode = coffeeCodeToJS(coffeeCode, @source, {
				bare: true
				header: false
				})
			dbg "jsCode", jsCode
		catch err
			croak err, "Original Code", coffeeCode

		if nonEmpty(lNeededSymbols)
			# --- Prepend needed imports
			lImports = buildImportList(lNeededSymbols, @source)
			dbg "lImports", lImports

			# --- append ';' to import statements
			lImports = for stmt in lImports
				stmt + ';'

			# --- joinBlocks() flattens all its arguments to array of strings
			jsCode = joinBlocks(lImports, jsCode)

		dbgReturn "CieloToJSMapper.finalizeBlock", jsCode
		return jsCode

# ---------------------------------------------------------------------------

export cieloFileToJS = (srcPath, destPath=undef, hOptions={}) ->
	# --- cielo => js
	#     Valid Options:
	#        saveAST
	#        force
	#        premapper
	#        postmapper

	if ! destPath?
		destPath = withExt(srcPath, '.js', {removeLeadingUnderScore:true})
	if hOptions.force || ! newerDestFileExists(srcPath, destPath)
		cieloCode = slurp(srcPath)
		if hOptions.saveAST
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
		jsCode = map({source: srcPath, content: cieloCode}, CieloToJSMapper)
		barf destPath, jsCode
	return
