# coffee.coffee

import {strict as assert} from 'assert'
import CoffeeScript from 'coffeescript'

import {
	unitTesting, croak, arrayToString, oneline,
	isEmpty, nonEmpty, words, undef, deepCopy,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {debug} from '@jdeighan/coffee-utils/debug'
import {mydir, pathTo, slurp, barf} from '@jdeighan/coffee-utils/fs'
import {indentLevel} from '@jdeighan/coffee-utils/indent'
import {
	CoffeeMapper, CoffeePostMapper, SmartInput,
	} from '@jdeighan/string-input'
import {ASTWalker} from '@jdeighan/string-input/tree'
import {tamlStringify} from '@jdeighan/string-input/taml'

# ---------------------------------------------------------------------------

export brewExpr = (expr, force=false) ->

	assert (indentLevel(expr)==0), "brewCoffee(): has indentation"

	if unitTesting && not force
		return expr
	try
		newexpr = CoffeeScript.compile(expr, {bare: true}).trim()

		# --- Remove any trailing semicolon
		pos = newexpr.length - 1
		if newexpr.substr(pos, 1) == ';'
			newexpr = newexpr.substr(0, pos)

	catch err
		croak err, "brewExpr", expr
	return newexpr

# ---------------------------------------------------------------------------

export brewCoffee = (lBlocks...) ->

	debug "enter brewCoffee()"

	lResult = []
	hAllNeeded = {}    # { <lib>: [ <symbol>, ...], ...}
	for blk,i in lBlocks
		debug "BLOCK #{i}", blk
		newblk = preProcessCoffee(blk)
		debug "NEW BLOCK", newblk

		# --- returns {<lib>: [<symbol>,... ],... }
		hNeeded = getNeededSymbols(newblk)
		mergeNeededSymbols(hAllNeeded, hNeeded)

		if unitTesting
			lResult.push newblk
		else
			try
				script = CoffeeScript.compile(newblk, {bare: true})
				debug "BREWED SCRIPT", script
				lResult.push postProcessCoffee(script)
			catch err
				log "Mapped Text:", newblk
				croak err, "Original Text", blk

	lResult.push buildImportList(hAllNeeded)
	return lResult

# ---------------------------------------------------------------------------

export preProcessCoffee = (code) ->
	# --- Removes blank lines and comments
	#     inteprets <== as svelte reactive statement or block

	assert (indentLevel(code)==0), "preProcessCoffee(): has indentation"

	oInput = new CoffeeMapper(code)
	newcode = oInput.getAllText()
	debug 'newcode', newcode
	return newcode

# ---------------------------------------------------------------------------

export postProcessCoffee = (code) ->
	# --- variable declaration immediately following one of:
	#        $:{
	#        $:
	#     should be moved above this line

	oInput = new CoffeePostMapper(code)
	return oInput.getAllText()

# ---------------------------------------------------------------------------

export addImports = (text, lImports) ->

	if not unitTesting
		lImports = for stmt in lImports
			"#{stmt};"
	return joinBlocks(lImports..., text)

# ---------------------------------------------------------------------------

export mergeNeededSymbols = (hAllNeeded, hNeeded) ->
  #  both are: { <lib>: [ <symbol>, ...], ...}

	for lib in Object.keys(hNeeded)
		if hAllNeeded[lib]?
			for sym in hNeeded[lib]
				if sym not in hAllNeeded[lib]
					hAllNeeded[lib].push sym
		else
			hAllNeeded[lib] = deepCopy(hNeeded[lib])
	return

# ---------------------------------------------------------------------------

export getNeededSymbols = (code, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	# --- returns { <lib>: [ <symbol>, ... ], ... }

	debug "enter getNeededSymbols()"
	hMissing = getMissingSymbols(code, hOptions)
	if isEmpty(hMissing)
		debug "return {} from getNeededSymbols() - no missing symbols"
		return {}

	hAvailSymbols = getAvailSymbols()
	if isEmpty(hAvailSymbols)
		debug "return {} from getNeededSymbols() - no avail symbols"
		return {}

	hNeeded = {}    # { <lib>: [ <symbol>, ...], ...}
	for sym in Object.keys(hMissing)
		if lib = hAvailSymbols[sym]
			if hNeeded[lib]
				hNeeded[lib].push(sym)
			else
				hNeeded[lib] = [sym]

	return hNeeded

# ---------------------------------------------------------------------------

export buildImportList = (hNeeded) ->

	lImports = []
	for lib in Object.keys(hNeeded).sort()
		symbols = hNeeded[lib].join(',')
		lImports.push "import {#{symbols}} from '#{lib}'"
	return lImports

# ---------------------------------------------------------------------------

export getNeededImports = (code, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	# --- returns lImports

	debug "enter getNeededImports()"
	hNeeded = getNeededSymbols(code, hOptions)

	lImports = []
	for lib in Object.keys(hNeeded)
		symbols = hNeeded[lib].join(',')
		lImports.push "import {#{symbols}} from '#{lib}'"
	debug "return from getNeededImports()"
	return lImports

# ---------------------------------------------------------------------------

export getMissingSymbols = (code, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast

	debug "enter getMissingSymbols()"
	try
		debug "COMPILE CODE", code
		ast = CoffeeScript.compile code, {ast: true}
		assert ast?, "getMissingSymbols(): ast is empty"
	catch err
		croak err, 'CODE (in getMissingSymbols)', code

	walker = new ASTWalker(ast)
	hMissingSymbols = walker.getMissingSymbols()
	if hOptions.dumpfile
		barf hOptions.dumpfile, "AST:\n" + tamlStringify(walker.ast)
	debug "return from getMissingSymbols()"
	return hMissingSymbols

# ---------------------------------------------------------------------------
# export to allow unit testing

export getAvailSymbols = () ->

	debug "enter getAvailSymbols()"
	searchFromDir = process.env.DIR_SYMBOLS || mydir(`import.meta.url`)
	debug "search for .symbols from '#{searchFromDir}'"
	filepath = pathTo('.symbols', searchFromDir, 'up')
	if not filepath?
		debug "return from getAvailSymbols() - no .symbols file found"
		return {}

	debug ".symbols file found at '#{filepath}'"

	class SymbolParser extends SmartInput
		# --- We want to allow blank lines and comments
		#     We want to allow continuation lines

		constructor: (content) ->

			super content
			@curLib = undef
			@hSymbols = {}

		mapString: (line, level) ->

			if level==0
				@curLib = line
			else if level==1
				assert @curLib?, "SymbolFileParser: curLib not defined"
				for symbol in words(line)
					assert not @hSymbols[symbol]?
					@hSymbols[symbol] = @curLib
			else
				croak "Bad .symbols file - level = #{level}"
			return undef   # doesn't matter what we return

		getSymbols: () ->

			@skipAll()
			return @hSymbols

	contents = slurp(filepath)
	debug 'Contents of .symbols', contents
	parser = new SymbolParser(contents)
	hSymbols = parser.getSymbols()
	debug "return #{oneline(hSymbols)} from getAvailSymbols()"
	return hSymbols
