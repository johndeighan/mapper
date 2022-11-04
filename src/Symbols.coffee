# Symbols.coffee

import {
	LOG, LOGVALUE, assert, croak,
	} from '@jdeighan/exceptions'
import {dbg, dbgEnter, dbgReturn} from '@jdeighan/exceptions/debug'
import {
	undef, defined, notdefined, isString, isArray, isEmpty, nonEmpty,
	uniq, words, escapeStr, OL,
	} from '@jdeighan/coffee-utils'
import {
	barf, slurp, pathTo, mkpath, parseSource,
	} from '@jdeighan/coffee-utils/fs'
import {splitLine, isUndented} from '@jdeighan/coffee-utils/indent'

import {Mapper} from '@jdeighan/mapper'
import {TreeMapper} from '@jdeighan/mapper/tree'
import {coffeeCodeToAST} from '@jdeighan/mapper/coffee'
import {ASTWalker} from '@jdeighan/mapper/ast'

# ---------------------------------------------------------------------------

export getNeededSymbols = (coffeeCode, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	#     NOTE: items in array returned will always be unique

	dbgEnter "getNeededSymbols", coffeeCode, hOptions
	assert isString(coffeeCode), "code not a string"
	assert isUndented(coffeeCode), "coffeeCode has indent"
	ast = coffeeCodeToAST(coffeeCode)
	dbg 'AST', ast

	walker = new ASTWalker(ast)
	hSymbolInfo = walker.walk()
	if hOptions.dumpfile
		barf hOptions.dumpfile, "AST:\n" + tamlStringify(ast)
	result = uniq(hSymbolInfo.lMissing)
	dbgReturn "getNeededSymbols", result
	return result

# ---------------------------------------------------------------------------

export buildImportList = (lNeededSymbols, source) ->

	dbgEnter "buildImportList", lNeededSymbols, source

	if isEmpty(lNeededSymbols)
		dbg 'no needed symbols'
		dbgReturn "buildImportList", []
		return []

	hLibs = {}   # { <lib>: [<symbol>, ... ], ... }
	lImports = []

	# --- { <sym>: {lib: <lib>, src: <name> }}
	hAvailSymbols = getAvailSymbols(source)

	for symbol in lNeededSymbols
		hSymbol = hAvailSymbols[symbol]
		if hSymbol?
			# --- symbol is available in lib
			{lib, src, isDefault} = hSymbol

			if isDefault
				lImports.push "import #{symbol} from '#{lib}'"
			else
				# --- build the needed string
				if src?
					str = "#{src} as #{symbol}"
				else
					str = symbol

				if hLibs[lib]?
					assert isArray(hLibs[lib]), "buildImportList(): not an array"
					hLibs[lib].push(str)
				else
					hLibs[lib] = [str]

	for lib in Object.keys(hLibs).sort()
		strSymbols = hLibs[lib].join(',')
		lImports.push "import {#{strSymbols}} from '#{lib}'"
	assert isArray(lImports), "lImports is not an array!"
	dbgReturn "buildImportList", lImports
	return lImports

# ---------------------------------------------------------------------------
# export only to allow unit testing

export getAvailSymbols = (source=undef) ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>, default: true},...}

	dbgEnter "getAvailSymbols", source
	if (source == undef)
		searchDir = process.cwd()
	else
		hSourceInfo = parseSource(source)
		searchDir = hSourceInfo.dir
		assert defined(searchDir), "No directory info for #{OL(source)}"
	dbg "search for .symbols from '#{searchDir}'"
	filepath = pathTo('.symbols', searchDir, {direction: 'up'})
	if notdefined(filepath)
		dbg 'no symbols file found'
		dbgReturn "getAvailSymbols", {}
		return {}

	hSymbols = getAvailSymbolsFrom(filepath)
	dbgReturn "getAvailSymbols", hSymbols
	return hSymbols

# ---------------------------------------------------------------------------

getAvailSymbolsFrom = (filepath) ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>}, ... }

	dbgEnter "getAvailSymbolsFrom", filepath

	contents = slurp(filepath)
	dbg 'Contents of .symbols', contents
	parser = new SymbolParser(filepath, contents)
	hAvailSymbols = parser.getAvailSymbols()
	dbgReturn "getAvailSymbolsFrom", hAvailSymbols
	return hAvailSymbols

# ---------------------------------------------------------------------------

class SymbolParser extends TreeMapper
	# --- Parse a .symbols file

	init: () ->

		@curLib = undef
		@hSymbols = {}

	# ..........................................................

	mapNode: (hLine) ->

		dbgEnter "SymbolParser.mapNode", hLine

		{str, level} = hLine
		if level==0
			@curLib = str
		else if level==1
			assert @curLib?, "curLib not defined"
			lWords = words(str)
			numWords = lWords.length

			for word,i in lWords
				lMatches = word.match(///^
						(\*?)
						([A-Za-z_][A-Za-z0-9_]*)
						(?:
							\/
							([A-Za-z_][A-Za-z0-9_]*)
							)?
						$///)
				assert defined(lMatches), "Bad word: #{OL(word)}"
				[_, isDefault, symbol, alt] = lMatches
				if nonEmpty(alt)
					src = symbol
					symbol = alt
				assert nonEmpty(symbol), "Bad word: #{OL(word)}"
				assert ! @hSymbols[symbol]?,
					"duplicate symbol #{symbol}"
				hDesc = {lib: @curLib}
				if src?
					hDesc.src = src
				if isDefault
					hDesc.isDefault = true
				@hSymbols[symbol] = hDesc
		else
			croak "Bad .symbols file - level = #{level}"
		dbgReturn "SymbolParser.mapNode", undef
		return undef   # doesn't matter what we return

	# ..........................................................

	getAvailSymbols: () ->

		@getBlock()
		return @hSymbols

# ---------------------------------------------------------------------------
