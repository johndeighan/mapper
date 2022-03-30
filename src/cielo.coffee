# cielo.coffee

import {
	undef, assert, croak, isString, uniq,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {indentLevel} from '@jdeighan/coffee-utils/indent'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {debug} from '@jdeighan/coffee-utils/debug'
import {
	withExt, slurp, barf, newerDestFileExists, shortenPath,
	} from '@jdeighan/coffee-utils/fs'

import {
	doMap, StringInput, SmartInput,
	} from '@jdeighan/string-input'
import {addHereDocType} from '@jdeighan/string-input/heredoc'
import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/string-input/symbols'
import {coffeeCodeToJS} from '@jdeighan/string-input/coffee'
import {FuncHereDoc} from '@jdeighan/string-input/func'

addHereDocType new FuncHereDoc()

export convertingCielo = true

# ---------------------------------------------------------------------------

export convertCielo = (flag) ->

	convertingCielo = flag
	return

# ---------------------------------------------------------------------------

export cieloCodeToJS = (lBlocks, hOptions={}) ->
	# --- cielo => js    lBlocks can be a string or array
	#     Valid Options:
	#        premapper:  SmartInput or subclass
	#        postmapper: SmartInput or subclass
	#        source: name of source file
	#        hCoffeeOptions  - passed to CoffeeScript.parse()
	#           default:
	#              bare: true
	#              header: false

	debug "enter cieloCodeToJS()"

	if isString(lBlocks)
		debug "string => array"
		lBlocks = [lBlocks]

	premapper = hOptions.premapper
	postmapper = hOptions.postmapper

	lNeededSymbols = []
	lNewBlocks = []
	for code,i in lBlocks
		assert (indentLevel(code)==0), "cieloCodeToJS(): has indentation"
		orgCode = code    # used in error messages
		debug "BLOCK #{i}", code

		# --- Even if no premapper is defined, this will handle
		#     continuation lines, HEREDOCs, etc.
		if premapper
			assert premapper instanceof StringInput, "bad premapper"
			newcode = doMap(premapper, code, hOptions.source)
		else
			newcode = doMap(SmartInput, code, hOptions.source)

		if newcode != code
			code = newcode
			debug "pre mapped", code

		# --- symbols will always be unique
		lNeededSymbols = lNeededSymbols.concat(getNeededSymbols(code))
		try
			if convertingCielo
				jsCode = coffeeCodeToJS(code, hOptions.hCoffeeOptions)
				debug "jsCode", jsCode
			else
				jsCode = code
			if postmapper
				assert postmapper instanceof StringInput, "bad postmapper"
				newcode = doMap(postmapper, jsCode, hOptions.source)
				if newcode != jsCode
					jsCode = newcode
					debug "post mapped", jsCode
			lNewBlocks.push jsCode
		catch err
			log "Code", code
			croak err, "Original Code", orgCode

	jsCode = joinBlocks(lNewBlocks...)
	debug "return from cieloCodeToJS()"
	return {
		jsCode,
		lNeededSymbols: uniq(lNeededSymbols)
		}

# ---------------------------------------------------------------------------

export addImports = (jsCode, lNeededSymbols, sep=undef) ->

	if ! sep?
		sep = if convertingCielo then ";\n" else "\n"

	# --- These import statements don't include a trailing ';'
	lImportStmts = buildImportList(lNeededSymbols)
	if lImportStmts.length == 0
		return jsCode
	return lImportStmts.join(sep) + sep + jsCode

# ---------------------------------------------------------------------------

export cieloFileToJS = (srcPath, destPath=undef, hOptions={}) ->
	# --- coffee => js
	#     Valid Options:
	#        saveAST
	#        force
	#        premapper
	#        postmapper

	if ! destPath?
		destPath = withExt(srcPath, '.js', {removeLeadingUnderScore:true})
	if hOptions.force || ! newerDestFileExists(srcPath, destPath)
		coffeeCode = slurp(srcPath)
		if hOptions.saveAST
			dumpfile = withExt(srcPath, '.ast')
			lNeeded = getNeededSymbols(coffeeCode, {dumpfile})
			if (lNeeded == undef) || (lNeeded.length == 0)
				debug "NO NEEDED SYMBOLS in #{shortenPath(destPath)}:"
			else
				n = lNeeded.length
				word = if (n==1) then'SYMBOL' else 'SYMBOLS'
				debug "#{n} NEEDED #{word} in #{shortenPath(destPath)}:"
				for sym in lNeeded
					debug "   - #{sym}"
		jsCode = cieloCodeToJS(coffeeCode, hOptions)
		barf destPath, jsCode
	return
