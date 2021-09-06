# code_utils.coffee

import {strict as assert} from 'assert'
import CoffeeScript from 'coffeescript'

import {
	say, undef, pass, croak, isEmpty, nonEmpty, isComment, isString,
	unitTesting, escapeStr, firstLine, isHash, arrayToString,
	} from '@jdeighan/coffee-utils'
import {slurp, barf, mydir, pathTo} from '@jdeighan/coffee-utils/fs'
import {splitLine} from '@jdeighan/coffee-utils/indent'
import {
	debug, debugging, startDebugging, endDebugging,
	} from '@jdeighan/coffee-utils/debug'

import {PLLParser} from '@jdeighan/string-input'
import {ASTWalker} from '@jdeighan/string-input/tree'
import {tamlStringify} from '@jdeighan/string-input/convert'

# ---------------------------------------------------------------------------

export getNeededImports = (code, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	#        debug: <bool>          - turn on debugging
	# --- returns lImports

	debug "enter getNeededImports()"
	hMissing = getMissingSymbols(code, hOptions)
	if isEmpty(hMissing)
		return []

	hSymbols = getAvailSymbols()
	if isEmpty(hSymbols)
		return []

	hNeeded = {}    # { <lib>: [<symbol>, ...], ...}
	for sym in Object.keys(hMissing)
		if lib = hSymbols[sym]
			if hNeeded[lib]
				hNeeded[lib].push(sym)
			else
				hNeeded[lib] = [sym]

	lImports = []
	for lib in Object.keys(hNeeded)
		symbols = hNeeded[lib].join(',')
		lImports.push "import {#{symbols}} from '#{lib}'"
	debug "return from getNeededImports()"
	return arrayToString(lImports)

# ---------------------------------------------------------------------------
# export to allow unit testing

export getMissingSymbols = (code, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	#        debug: <bool>          - turn on debugging

	if hOptions.debug
		startDebugging
	debug "enter getMissingSymbols()"

	try
		debug code, "COMPILE CODE:"
		ast = CoffeeScript.compile code, {ast: true}
		assert ast?, "getMissingSymbols(): ast is empty"
	catch err
		say "ERROR in getMissingSymbols(): #{err.message}"
		say code, "CODE:"

	walker = new ASTWalker(ast)
	hMissingSymbols = walker.getMissingSymbols()
	if hOptions.debug
		endDebugging
	if hOptions.dumpfile
		barf hOptions.dumpfile, "AST:\n" + tamlStringify(walker.ast)
	debug "return from getMissingSymbols()"
	return hMissingSymbols

# ---------------------------------------------------------------------------
# export to allow unit testing

export getAvailSymbols = () ->

	debug "enter getAvailSymbols()"
	searchFromDir = mydir(`import.meta.url`)
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
