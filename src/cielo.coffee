# cielo.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, OL, replaceVars, className,
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
import {doMap, Mapper} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export cieloCodeToJS = (cieloCode, source=undef, hOptions={}) ->
	# --- cielo => js
	#     Valid Options:
	#        premapper:  Mapper or subclass
	#        postmapper: Mapper or subclass - optional
	#        hCoffeeOptions  - passed to CoffeeScript.parse()
	#           default:
	#              bare: true
	#              header: false
	#     If hOptions is a string, it's assumed to be the source

	debug "enter cieloCodeToJS()", cieloCode, source, hOptions

	assert isUndented(cieloCode), "cieloCode has indent"
	assert isHash(hOptions), "hOptions not a hash"

	if hOptions.premapper
		premapper = hOptions.premapper
		assert (premapper.prototype instanceof TreeWalker) || (premapper == TreeWalker),
				"premapper should be a TreeWalker"
	else
		premapper = TreeWalker
	postmapper = hOptions.postmapper   # may be undef

	# --- Handles extension lines, HEREDOCs, etc.
	debug "Apply premapper #{className(premapper)}"
	coffeeCode = doMap(premapper, source, cieloCode)
	if coffeeCode != cieloCode
		assert isUndented(coffeeCode), "coffeeCode has indent"
		debug "coffeeCode", coffeeCode

	# --- symbols will always be unique
	#     We can only get needed symbols from coffee code, not JS code
	lNeededSymbols = getNeededSymbols(coffeeCode)
	debug "#{lNeededSymbols.length} needed symbols", lNeededSymbols

	try
		hCoffeeOptions = hOptions.hCoffeeOptions
		jsPreCode = coffeeCodeToJS(coffeeCode, source, hCoffeeOptions)
		debug "jsPreCode", jsPreCode
		if postmapper
			jsCode = doMap(postmapper, source, jsPreCode)
			if jsCode != jsPreCode
				debug "post mapped", jsCode
		else
			jsCode = jsPreCode
	catch err
		croak err, "Original Code", cieloCode

	# --- Prepend needed imports
	lImports = buildImportList(lNeededSymbols, source)
	debug "lImports", lImports
	assert isArray(lImports), "cieloCodeToJS(): lImports is not an array"

	# --- append ';' to import statements
	lImports = for stmt in lImports
		stmt + ';'

	# --- joinBlocks() flattens all its arguments to array of strings
	jsCode = joinBlocks(lImports, jsCode)
	debug "return from cieloCodeToJS()", jsCode
	return jsCode

# ---------------------------------------------------------------------------

export cieloCodeToCoffee = (cieloCode, source=undef, hOptions={}) ->
	# --- cielo => coffee
	#     Valid Options:
	#        premapper:  Mapper or subclass
	#        postmapper: Mapper or subclass - optional
	#        hCoffeeOptions  - passed to CoffeeScript.parse()
	#           default:
	#              bare: true
	#              header: false
	#     If hOptions is a string, it's assumed to be the source

	debug "enter cieloCodeToCoffee()", cieloCode, source, hOptions

	assert isUndented(cieloCode), "cieloCode has indent"
	assert isHash(hOptions), "hOptions not a hash"

	if hOptions.premapper
		premapper = hOptions.premapper
		assert (premapper.prototype instanceof TreeWalker) || (premapper == TreeWalker),
				"premapper should be a TreeWalker"
	else
		premapper = TreeWalker

	postmapper = hOptions.postmapper   # may be undef

	# --- Handles extension lines, HEREDOCs, etc.
	debug "Apply premapper #{className(premapper)}"
	coffeeCode = doMap(premapper, source, cieloCode)
	if coffeeCode != cieloCode
		assert isUndented(coffeeCode), "coffeeCode has indent"
		debug "coffeeCode", coffeeCode

	# --- symbols will always be unique
	#     We can only get needed symbols from coffee code, not JS code
	lNeededSymbols = getNeededSymbols(coffeeCode)
	debug "#{lNeededSymbols.length} needed symbols", lNeededSymbols

	if postmapper
		newCoffeeCode = doMap(postmapper, source, coffeeCode)
		if (newCoffeeCode != coffeeCode)
			coffeeCode = newCoffeeCode
			debug "post mapped", coffeeCode

	# --- Prepend needed imports
	lImports = buildImportList(lNeededSymbols, source)
	debug "lImports", lImports
	assert isArray(lImports), "cieloCodeToCoffee(): lImports is not an array"

	# --- joinBlocks() flattens all its arguments to array of strings
	coffeeCode = joinBlocks(lImports, coffeeCode)
	debug "return from cieloCodeToCoffee()", coffeeCode
	return coffeeCode

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
		jsCode = cieloCodeToJS(cieloCode, srcPath, hOptions)
		barf destPath, jsCode
	return
