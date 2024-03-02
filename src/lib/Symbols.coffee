# Symbols.coffee

import {
	undef, defined, notdefined, isString, isArray, isEmpty, nonEmpty,
	uniq, words, escapeStr, OL, getOptions,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {barf, parsePath} from '@jdeighan/base-utils/fs'
import {pathTo} from '@jdeighan/coffee-utils/fs'
import {splitLine, isUndented} from '@jdeighan/base-utils/indent'

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
	{dumpFile} = getOptions(hOptions)
	assert isString(coffeeCode), "code not a string"
	assert isUndented(coffeeCode), "coffeeCode has indent"
	ast = coffeeCodeToAST(coffeeCode)
	dbg 'AST', ast

	walker = new ASTWalker(ast)
	hSymbolInfo = walker.walk()
	if dumpFile
		barf "AST:\n#{tamlStringify(ast)}", dumpFile
	result = uniq(hSymbolInfo.lMissing)
	dbgReturn "getNeededSymbols", result
	return result

# ---------------------------------------------------------------------------

export buildImportList = (lNeededSymbols, source) ->

	dbgEnter "buildImportList", lNeededSymbols, source

	if isEmpty(lNeededSymbols)
		dbg 'no needed symbols'
		dbgReturn "buildImportList", []
		return {lImportStmts: [], lNotFound: []}

	hLibs = {}   # { <lib>: [<symbol>, ... ], ... }
	lImportStmts = []
	lNotFound = []

	# --- { <sym>: {lib: <lib>, src: <name> }}
	hAvailSymbols = getAvailSymbols(source)
	dbg 'hAvailSymbols', hAvailSymbols

	for symbol in lNeededSymbols
		assert isString(symbol), "not a string"
		hSymbol = hAvailSymbols[symbol]
		if defined(hSymbol)

			# --- symbol is available in lib
			{lib, src, isDefault} = hSymbol

			if isDefault
				lImportStmts.push "import #{symbol} from '#{lib}'"
			else
				# --- build the needed string
				if defined(src)
					str = "#{src} as #{symbol}"
				else
					str = symbol

				if hLibs[lib]?
					assert isArray(hLibs[lib]), "buildImportList(): not an array"
					hLibs[lib].push(str)
				else
					hLibs[lib] = [str]
		else
			lNotFound.push symbol

	for lib in Object.keys(hLibs).sort()
		strSymbols = hLibs[lib].join(',')
		lImportStmts.push "import {#{strSymbols}} from '#{lib}'"
	assert isArray(lImportStmts), "lImportStmts is not an array!"
	result = {
		lNotFound
		lImportStmts
		}
	dbgReturn "buildImportList", result
	return result

# ---------------------------------------------------------------------------
# export only to allow unit testing

export getAvailSymbols = (sourceFile=undef) ->
	# --- returns { <symbol>: {
	#                  lib: <lib>,
	#                  src: <name>,
	#                  default: true
	#                  },...
	#                }

	dbgEnter "getAvailSymbols", sourceFile
	if notdefined(sourceFile)
		searchDir = process.cwd()
		dbg "searchDir is current dir: #{OL(searchDir)}"
	else
		hSourceInfo = parsePath(sourceFile)
		searchDir = hSourceInfo.dir
		assert defined(searchDir), "No directory info for #{OL(sourceFile)}"
		dbg "searchDir is #{OL(searchDir)}"

	filePath = pathTo('.symbols', searchDir, {direction: 'up'})
	if defined(filePath)
		dbg ".symbols file is #{OL(filePath)}"
		hSymbols = getAvailSymbolsFrom(filePath)
	else
		dbg 'no .symbols file found'
		hSymbols = {}
	dbgReturn "getAvailSymbols", hSymbols
	return hSymbols

# ---------------------------------------------------------------------------
# export only to allow unit testing

export getAvailSymbolsFrom = (filepath) ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>}, ... }

	dbgEnter "getAvailSymbolsFrom", filepath

	parser = new SymbolParser({source: filepath})
	hAvailSymbols = parser.getAvailSymbols()
	dbgReturn "getAvailSymbolsFrom", hAvailSymbols
	return hAvailSymbols

# ---------------------------------------------------------------------------

class SymbolParser extends TreeMapper
	# --- Parse a .symbols file

	constructor: (hInput, options) ->

		super hInput, options
		@curLib = undef
		@hSymbols = {}

	# ..........................................................

	getUserObj: (hLine) ->

		dbgEnter "SymbolParser.getUserObj", hLine

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
		dbgReturn "SymbolParser.getUserObj", undef
		return undef   # doesn't matter what we return

	# ..........................................................

	getAvailSymbols: () ->

		@getBlock()
		return @hSymbols

# ---------------------------------------------------------------------------
