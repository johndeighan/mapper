# Symbols.coffee

import {
	assert, undef, defined, isString, isArray, isEmpty, nonEmpty,
	croak, uniq, words, escapeStr, OL,
	} from '@jdeighan/coffee-utils'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {
	barf, slurp, pathTo, mkpath, parseSource,
	} from '@jdeighan/coffee-utils/fs'
import {debug} from '@jdeighan/coffee-utils/debug'
import {splitLine} from '@jdeighan/coffee-utils/indent'

import {Mapper} from '@jdeighan/mapper'
import {coffeeCodeToAST} from '@jdeighan/mapper/coffee'
import {ASTWalker} from '@jdeighan/mapper/ast'

# ---------------------------------------------------------------------------

export getNeededSymbols = (coffeeCode, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	#     NOTE: items in array returned will always be unique

	debug "enter getNeededSymbols()", coffeeCode
	assert isString(coffeeCode), "getNeededSymbols(): code not a string"
	ast = coffeeCodeToAST(coffeeCode)

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
	assert isArray(lImports), "lImports is not an array!"
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
	parser = new SymbolParser(filepath, contents)
	hAvailSymbols = parser.getAvailSymbols()
	debug "hAvailSymbols", hAvailSymbols
	debug "return from getAvailSymbolsFrom()"
	return hAvailSymbols

# ---------------------------------------------------------------------------

class SymbolParser extends Mapper
	# --- Parse a .symbols file

	constructor: (content, source) ->

		super content, source
		@curLib = undef
		@hSymbols = {}

	# ..........................................................
	# ignore empty lines and comments

	handleEmptyLine: (line) -> return undef
	handleComment:   (line) -> return undef

	# ..........................................................

	map: (full_line) ->

		[level, line] = splitLine(full_line)
		if level==0
			@curLib = line.trim()
		else if level==1
			assert @curLib?, "mapString(): curLib not defined"
			lWords = words(line)
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

	getAvailSymbols: () ->

		@getBlock()
		return @hSymbols

# ---------------------------------------------------------------------------
