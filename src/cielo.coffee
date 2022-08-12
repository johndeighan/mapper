# cielo.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, defined, OL, replaceVars, className,
	isEmpty, nonEmpty, isString, isHash, isArray,
	} from '@jdeighan/coffee-utils'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {
	indentLevel, isUndented, splitLine,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	withExt, slurp, barf, newerDestFileExists, shortenPath,
	} from '@jdeighan/coffee-utils/fs'

import {TreeWalker} from '@jdeighan/mapper/tree'
import {coffeeCodeToJS} from '@jdeighan/mapper/coffee'
import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'
import {map, Mapper} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export class CieloToJSMapper extends TreeWalker

	finalizeBlock: (coffeeCode) ->

		debug "enter CieloToJSMapper.finalizeBlock()", coffeeCode
		lNeededSymbols = getNeededSymbols(coffeeCode)
		debug "#{lNeededSymbols.length} needed symbols", lNeededSymbols
		try
			jsCode = coffeeCodeToJS(coffeeCode, @source, {
				bare: true
				header: false
				})
			debug "jsCode", jsCode
		catch err
			croak err, "Original Code", coffeeCode

		if nonEmpty(lNeededSymbols)
			# --- Prepend needed imports
			lImports = buildImportList(lNeededSymbols, @source)
			debug "lImports", lImports

			# --- append ';' to import statements
			lImports = for stmt in lImports
				stmt + ';'

			# --- joinBlocks() flattens all its arguments to array of strings
			jsCode = joinBlocks(lImports, jsCode)

		debug "return from CieloToJSMapper.finalizeBlock()", jsCode
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
				debug "NO NEEDED SYMBOLS in #{shortenPath(destPath)}:"
			else
				n = lNeeded.length
				word = if (n==1) then'SYMBOL' else 'SYMBOLS'
				debug "#{n} NEEDED #{word} in #{shortenPath(destPath)}:"
				for sym in lNeeded
					debug "   - #{sym}"
		jsCode = map(srcPath, cieloCode, CieloToJSMapper)
		barf destPath, jsCode
	return
