# Symbols.coffee

import {
	LOG, LOGVALUE, assert, croak, debug,
	} from '@jdeighan/exceptions'
import {
	undef, defined, isString, isArray, isEmpty, nonEmpty,
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

	debug "enter getNeededSymbols()", coffeeCode, hOptions
	assert isString(coffeeCode), "code not a string"
	assert isUndented(coffeeCode), "coffeeCode has indent"
	ast = coffeeCodeToAST(coffeeCode)
	debug 'AST', ast

	walker = new ASTWalker(ast)
	hSymbolInfo = walker.getSymbols()
	if hOptions.dumpfile
		barf hOptions.dumpfile, "AST:\n" + tamlStringify(ast)
	result = uniq(hSymbolInfo.lNeeded)
	debug "return from getNeededSymbols()", result
	return result

# ---------------------------------------------------------------------------

export buildImportList = (lNeededSymbols, source) ->

	debug "enter buildImportList()", lNeededSymbols, source

	if isEmpty(lNeededSymbols)
		debug "return from buildImportList() - no needed symbols"
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
	debug "return from buildImportList()", lImports
	return lImports

# ---------------------------------------------------------------------------
# export only to allow unit testing

export getAvailSymbols = (source=undef) ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>, default: true},...}

	debug "enter getAvailSymbols()", source
	if (source == undef)
		searchDir = process.cwd()
	else
		hSourceInfo = parseSource(source)
		searchDir = hSourceInfo.dir
		assert defined(searchDir), "No directory info for #{OL(source)}"
	debug "search for .symbols from '#{searchDir}'"
	filepath = pathTo('.symbols', searchDir, {direction: 'up'})
	if ! filepath?
		debug "return from getAvailSymbols() - no .symbols file found"
		return {}

	hSymbols = getAvailSymbolsFrom(filepath)
	debug "return from getAvailSymbols()", hSymbols
	return hSymbols

# ---------------------------------------------------------------------------

getAvailSymbolsFrom = (filepath) ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>}, ... }

	debug "enter getAvailSymbolsFrom()", filepath

	contents = slurp(filepath)
	debug 'Contents of .symbols', contents
	parser = new SymbolParser(filepath, contents)
	hAvailSymbols = parser.getAvailSymbols()
	debug "return from getAvailSymbolsFrom()", hAvailSymbols
	return hAvailSymbols

# ---------------------------------------------------------------------------

class SymbolParser extends TreeMapper
	# --- Parse a .symbols file

	init: () ->

		@curLib = undef
		@hSymbols = {}

	# ..........................................................

	mapNode: (hLine) ->

		debug "enter SymbolParser.mapNode()", hLine

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
		debug "return from SymbolParser.mapNode()", undef
		return undef   # doesn't matter what we return

	# ..........................................................

	getAvailSymbols: () ->

		@getBlock()
		return @hSymbols

# ---------------------------------------------------------------------------
