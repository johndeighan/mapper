# Symbols.coffee

import CoffeeScript from 'coffeescript'

import {
	assert, undef, isString, isArray, croak, uniq, words, escapeStr,
	} from '@jdeighan/coffee-utils'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {
	barf, slurp, pathTo, mkpath, parseSource,
	} from '@jdeighan/coffee-utils/fs'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Mapper, CieloMapper} from '@jdeighan/mapper'
import {ASTWalker} from '@jdeighan/mapper/walker'

# ---------------------------------------------------------------------------

export getNeededSymbols = (coffeeCode, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	#     NOTE: items in array returned will always be unique

	debug "enter getNeededSymbols()", coffeeCode
	assert isString(coffeeCode), "getNeededSymbols(): code not a string"
	try
		ast = CoffeeScript.compile coffeeCode, {ast: true}
		assert ast?, "getNeededSymbols(): ast is empty"
	catch err
		LOG 'CODE (in getNeededSymbols)', coffeeCode
		croak err

	walker = new ASTWalker(ast)
	hSymbolInfo = walker.getSymbols()
	if hOptions.dumpfile
		barf hOptions.dumpfile, "AST:\n" + tamlStringify(ast)
	debug "return from getNeededSymbols()"
	return uniq(hSymbolInfo.lNeeded)

# ---------------------------------------------------------------------------

export buildImportList = (lNeededSymbols, source) ->

	debug "enter buildImportList('#{escapeStr(source)}')", lNeededSymbols

	if !lNeededSymbols || (lNeededSymbols.length == 0)
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
	debug "return from buildImportList()", lImports
	return lImports

# ---------------------------------------------------------------------------
# export only to allow unit testing

export getAvailSymbols = (source) ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>, default: true},...}

	debug "enter getAvailSymbols('#{escapeStr(source)}')"
	hSourceInfo = parseSource(source)
	searchDir = hSourceInfo.dir
	debug "search for .symbols from '#{searchDir}'"
	filepath = pathTo('.symbols', searchDir, 'up')
	if ! filepath?
		debug "return from getAvailSymbols() - no .symbols file found"
		return {}

	hSymbols = getAvailSymbolsFrom(filepath)
	debug "hSymbols", hSymbols
	debug "return from getAvailSymbols()", hSymbols
	return hSymbols

# ---------------------------------------------------------------------------

getAvailSymbolsFrom = (filepath) ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>}, ... }

	debug "enter getAvailSymbolsFrom('#{filepath}')"

	contents = slurp(filepath)
	debug 'Contents of .symbols', contents
	parser = new SymbolParser(contents, filepath)
	hSymbols = parser.getSymbols()
	debug "hSymbols", hSymbols
	debug "return from getAvailSymbolsFrom()"

	return hSymbols

# ---------------------------------------------------------------------------

class SymbolParser extends CieloMapper
	# --- Parse a .symbols file

	constructor: (content, source) ->

		super content, source
		@curLib = undef
		@hSymbols = {}

	mapString: (line, level) ->

		if level==0
			@curLib = line
		else if level==1
			assert @curLib?, "mapString(): curLib not defined"
			lWords = words(line)
			numWords = lWords.length

			for word,i in lWords
				symbol = src = undef

				# --- set variables symbol and possibly src
				if lMatches = word.match(/^(\*?)([A-Za-z_][A-Za-z0-9_]*)$/)
					[_, isDefault, symbol] = lMatches
					# --- word is an identifier (skip words that contain '(' or ')')
					if (i+2 < numWords)
						nextWord = lWords[i+1]
						if (nextWord == '(as')
							lMatches = lWords[i+2].match(/^([A-Za-z_][A-Za-z0-9_]*)\)$/)
							if lMatches
								src = symbol
								symbol = lMatches[1]

				if symbol?
					assert ! @hSymbols[symbol]?,
						"SymbolParser: duplicate symbol #{symbol}"
					hDesc = {lib: @curLib}
					if src?
						hDesc.src = src
					if isDefault
						hDesc.isDefault = true
					@hSymbols[symbol] = hDesc
		else
			croak "Bad .symbols file - level = #{level}"
		return undef   # doesn't matter what we return

	getSymbols: () ->

		@getAll()
		return @hSymbols

# ---------------------------------------------------------------------------
