# code_utils.coffee

import {strict as assert} from 'assert'
import CoffeeScript from 'coffeescript'

import {
	say, undef, pass, error, isEmpty, nonEmpty, isComment, isString,
	unitTesting, escapeStr, firstLine,
	} from '@jdeighan/coffee-utils'
import {slurp, barf, mydir, pathTo} from '@jdeighan/coffee-utils/fs'
import {
	debug, debugging, startDebugging, endDebugging,
	} from '@jdeighan/coffee-utils/debug'
import {tamlStringify} from '@jdeighan/string-input/convert'
import {splitLine} from '@jdeighan/coffee-utils/indent'
import {CodeWalker} from './CodeWalker.js'
import {PLLParser} from '@jdeighan/string-input/pll'

# ---------------------------------------------------------------------------

export getMissingSymbols = (code, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	#        debug: <bool>          - turn on debugging

	if hOptions.debug
		startDebugging
	walker = new CodeWalker(code)
	hMissingSymbols = walker.getMissingSymbols()
	if hOptions.debug
		endDebugging
	if hOptions.dumpfile
		barf hOptions.dumpfile, "AST:\n" + tamlStringify(walker.ast)
	return hMissingSymbols

# ---------------------------------------------------------------------------

export getAvailSymbols = () ->

	filepath = pathTo('.symbols', mydir(`import.meta.url`), 'up')
	contents = slurp(filepath)

	class SymbolParser extends PLLParser

		mapString: (line, level) ->
			if level==0
				return line
			else if level==1
				return line.split(/\s+/).filter((s) -> nonEmpty(s))
			else
				error "Bad .symbols file - level = #{level}"

	tree = new SymbolParser(contents).getTree()

	hSymbols = {}     # { <symbol>: <lib>, ... }
	for {node: lib, body} in tree
		for hItem in body
			for sym in hItem.node
				assert not hSymbols[sym]?, "dup symbol: '#{sym}'"
				hSymbols[sym] = lib
	return hSymbols

# ---------------------------------------------------------------------------

export getNeededImports = (code, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	#        debug: <bool>          - turn on debugging
	# --- returns [lImports, lStillMissing]

	hMissing = getMissingSymbols(code, hOptions)
	hSymbols = getAvailSymbols()

	hNeeded = {}    # { <lib>: [<symbol>, ...], ...}
	lStillMissing = []
	for sym in Object.keys(hMissing)
		if lib = hSymbols[sym]
			if hNeeded[lib]
				hNeeded[lib].push(sym)
			else
				hNeeded[lib] = [sym]
		else
			lStillMissing.push(sym)
	lImports = []
	for lib in Object.keys(hNeeded)
		symbols = hNeeded[lib].join(',')
		lImports.push "import {#{symbols}} from '#{lib}'"
	return [lImports, lStillMissing]
