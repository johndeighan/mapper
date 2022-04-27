# cielo.coffee

import {
	undef, assert, croak, OL, replaceVars,
	isEmpty, nonEmpty, isString, isHash,
	} from '@jdeighan/coffee-utils'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {indentLevel, splitLine} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'
import {
	withExt, slurp, barf, newerDestFileExists, shortenPath,
	} from '@jdeighan/coffee-utils/fs'

import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'
import {TAMLHereDoc} from '@jdeighan/mapper/taml'
import {
	addHereDocType, lineToParts, mapHereDoc,
	} from '@jdeighan/mapper/heredoc'
import {doMap, Mapper} from '@jdeighan/mapper'
import {FuncHereDoc} from '@jdeighan/mapper/func'
import {coffeeCodeToJS} from '@jdeighan/mapper/coffee'
import {CieloMapper} from '@jdeighan/mapper/cielomapper'

addHereDocType new FuncHereDoc()
addHereDocType new TAMLHereDoc()

export convertingCielo = true

# ---------------------------------------------------------------------------

export convertCielo = (flag) ->

	convertingCielo = flag
	return

# ---------------------------------------------------------------------------

export cieloCodeToJS = (cieloCode, hOptions) ->
	# --- cielo => js
	#     Valid Options:
	#        premapper:  CieloMapper or subclass
	#        postmapper: CieloMapper or subclass
	#        source: name of source file
	#        hCoffeeOptions  - passed to CoffeeScript.parse()
	#           default:
	#              bare: true
	#              header: false

	debug 'hOptions', hOptions

	debug "enter cieloCodeToJS()"
	debug "cieloCode", cieloCode

	assert (indentLevel(cieloCode)==0), "cieloCodeToJS(): has indentation"

	if isString(hOptions)
		source = hOptions
		premapper = CieloMapper
		postmapper = undef
	else if isHash(hOptions)
		premapper = hOptions.premapper || CieloMapper
		postmapper = hOptions.postmapper   # may be undef
		source = hOptions.source
	else
		croak "cieloCodeToJS(): Invalid 2nd parm: #{typeof hOptions}"
	assert source?, "cieloCodeToJS(): Missing source"

	# --- Even if no premapper is defined, this will handle
	#     continuation lines, HEREDOCs, etc.
	coffeeCode = doMap(premapper, cieloCode, source)
	if coffeeCode != cieloCode
		debug "coffeeCode", coffeeCode

	# --- symbols will always be unique
	lNeededSymbols = getNeededSymbols(coffeeCode)
	debug "#{lNeededSymbols.length} needed symbols: #{lNeededSymbols}"

	try
		if convertingCielo
			jsPreCode = coffeeCodeToJS(coffeeCode, hOptions.hCoffeeOptions)
			debug "jsPreCode", jsPreCode
		else
			jsPreCode = cieloCode
		if postmapper
			jsCode = doMap(postmapper, jsPreCode, source)
			if jsCode != jsPreCode
				debug "post mapped", jsCode
		else
			jsCode = jsPreCode
	catch err
		croak err, "Original Code", cieloCode

	imports = buildImportList(lNeededSymbols, source).join("\n")
	debug "imports", imports
	debug "return from cieloCodeToJS()", jsCode
	return {jsCode, imports}

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
		{imports, jsCode} = cieloCodeToJS(cieloCode, hOptions)
		barf destPath, [imports, jsCode]
	return
