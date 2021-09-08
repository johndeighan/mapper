# code_utils.coffee

import {strict as assert} from 'assert'
import CoffeeScript from 'coffeescript'

import {
	log, undef, pass, croak, isEmpty, nonEmpty, isComment, isString,
	unitTesting, escapeStr, firstLine, isHash, arrayToString, deepCopy,
	} from '@jdeighan/coffee-utils'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {slurp, barf, mydir, pathTo} from '@jdeighan/coffee-utils/fs'
import {splitLine} from '@jdeighan/coffee-utils/indent'
import {
	debug, debugging, startDebugging, endDebugging,
	} from '@jdeighan/coffee-utils/debug'

import {PLLParser} from '@jdeighan/string-input'
import {ASTWalker} from '@jdeighan/string-input/tree'
import {tamlStringify} from '@jdeighan/string-input/convert'

# ---------------------------------------------------------------------------

export prependImports = (text, lImports) ->

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
	for lib in Object.keys(hNeeded)
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
		debug code, "COMPILE CODE (in getMissingSymbols):"
		ast = CoffeeScript.compile code, {ast: true}
		assert ast?, "getMissingSymbols(): ast is empty"
	catch err
		croak err, code, 'CODE (in getMissingSymbols)'

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
		return {}

	debug ".symbols file found at '#{filepath}'"
	contents = slurp(filepath)

	class SymbolParser extends PLLParser

		mapString: (line, level) ->
			if level==0
				return line
			else if level==1
				return line.split(/\s+/).filter((s) -> nonEmpty(s))
			else
				croak "Bad .symbols file - level = #{level}"

	tree = new SymbolParser(contents).getTree()

	hSymbols = {}     # { <symbol>: <lib>, ... }
	for {node: lib, body} in tree
		for hItem in body
			for sym in hItem.node
				assert not hSymbols[sym]?, "dup symbol: '#{sym}'"
				hSymbols[sym] = lib
	debug "return from getAvailSymbols()"
	return hSymbols
