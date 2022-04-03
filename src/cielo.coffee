# cielo.coffee

import {
	undef, assert, croak, isString, uniq,
	} from '@jdeighan/coffee-utils'
import {log, DEBUG} from '@jdeighan/coffee-utils/log'
import {indentLevel} from '@jdeighan/coffee-utils/indent'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {debug} from '@jdeighan/coffee-utils/debug'
import {
	withExt, slurp, barf, newerDestFileExists, shortenPath,
	} from '@jdeighan/coffee-utils/fs'

import {doMap, Mapper, SmartMapper} from '@jdeighan/mapper'
import {addHereDocType} from '@jdeighan/mapper/heredoc'
import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'
import {coffeeCodeToJS} from '@jdeighan/mapper/coffee'
import {FuncHereDoc} from '@jdeighan/mapper/func'
import {TAMLHereDoc} from '@jdeighan/mapper/taml'

addHereDocType new FuncHereDoc()
addHereDocType new TAMLHereDoc()

export convertingCielo = true

# ---------------------------------------------------------------------------

export convertCielo = (flag) ->

	convertingCielo = flag
	return

# ---------------------------------------------------------------------------

export cieloCodeToJS = (cieloCode, hOptions={}) ->
	# --- cielo => js
	#     Valid Options:
	#        premapper:  SmartMapper or subclass
	#        postmapper: SmartMapper or subclass
	#        source: name of source file
	#        hCoffeeOptions  - passed to CoffeeScript.parse()
	#           default:
	#              bare: true
	#              header: false

	debug "enter cieloCodeToJS()"
	debug "cieloCode", cieloCode

	assert (indentLevel(cieloCode)==0), "cieloCodeToJS(): has indentation"

	premapper = hOptions.premapper || SmartMapper
	postmapper = hOptions.postmapper   # may be undef
	source = hOptions.source

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
			jsPostCode = doMap(postmapper, jsPreCode, source)
			if jsPostCode != jsPreCode
				debug "post mapped", jsPostCode
		else
			jsPostCode = jsPreCode

		# --- A separator can be specified as 3rd arg
		#     But by default, the variable convertCielo is checked
		#        and the appropriate separator is used
		jsCode = addImports(jsPostCode, lNeededSymbols)

		if jsCode != jsPostCode
			debug "with imports", jsCode
	catch err
		croak err, "Original Code", cieloCode
	debug "return from cieloCodeToJS()", jsCode
	return jsCode

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
		jsCode = cieloCodeToJS(cieloCode, hOptions)
		barf destPath, jsCode
	return
