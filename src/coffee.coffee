# coffee.coffee

import CoffeeScript from 'coffeescript'

import {
	assert, croak, OL, escapeStr, isArray, isString,
	isEmpty, nonEmpty, words, undef, deepCopy, uniq, say,
	} from '@jdeighan/coffee-utils'
import {log, tamlStringify} from '@jdeighan/coffee-utils/log'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {debug} from '@jdeighan/coffee-utils/debug'
import {
	mydir, pathTo, withExt, slurp, barf, newerDestFileExists,
	shortenPath,
	} from '@jdeighan/coffee-utils/fs'
import {indentLevel, indented} from '@jdeighan/coffee-utils/indent'
import {StringInput, SmartInput} from '@jdeighan/string-input'
import {ASTWalker} from '@jdeighan/string-input/tree'

convert = true

# ---------------------------------------------------------------------------

export convertCoffee = (flag) ->

	convert = flag
	return

# ---------------------------------------------------------------------------

export brewExpr = (expr, force=false) ->

	assert (indentLevel(expr)==0), "brewExpr(): has indentation"

	if ! convert && ! force
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

export preBrewCoffee = (lBlocks...) ->

	debug "enter preBrewCoffee()"

	lNeededSymbols = []
	lNewBlocks = []
	for blk,i in lBlocks
		debug "BLOCK #{i}", blk
		newblk = preProcessCoffee(blk)
		debug "NEW BLOCK", newblk

		# --- will always be unique
		lNeededSymbols = getNeededSymbols(newblk)
		if convert
			try
				script = CoffeeScript.compile(newblk, {bare: true})
				debug "BREWED SCRIPT", script
				lNewBlocks.push postProcessCoffee(script)
			catch err
				log "Mapped Text:", newblk
				croak err, "Original Text", blk
		else
			lNewBlocks.push newblk

	return [buildImportBlock(lNeededSymbols), lNewBlocks...]

# ---------------------------------------------------------------------------

export brewCoffeeStr = (code) ->
	# --- coffee => js

	assert isString(code), "brewCoffeeStr(): code is not a string"
	lBlocks = preBrewCoffee(code)
	newcode = joinBlocks(lBlocks...)

	debug 'CODE', code
	debug 'NEW CODE', newcode

	return newcode

# ---------------------------------------------------------------------------

brewCoffeeFile = (srcPath, destPath=undef, hOptions={}) ->
	# --- coffee => js
	#     Valid Options:
	#        saveAST
	#        force

	if ! destPath?
		destPath = withExt(srcPath, '.js', {removeLeadingUnderScore:true})
	if hOptions.force || ! newerDestFileExists(srcPath, destPath)
		coffeeCode = slurp(srcPath)
		if hOptions.saveAST
			dumpfile = withExt(srcPath, '.ast')
			lNeeded = getNeededSymbols(coffeeCode, {dumpfile})
			if (lNeeded == undef) || (lNeeded.length == 0)
				debug "NO NEEDED SYMBOLS in #{shortenPath(destPath)}:"
			else
				n = lNeeded.length
				word = if (n==1) then'SYMBOL' else 'SYMBOLS'
				debug "#{n} NEEDED #{word} in #{shortenPath(destPath)}:"
				for sym in lNeeded
					debug "   - #{sym}"
		jsCode = brewCoffeeStr(coffeeCode)
		barf destPath, jsCode
	return

# ---------------------------------------------------------------------------

###

- converts
		<varname> <== <expr>

	to:
		`$:`
		<varname> = <expr>

	then to to:
		var <varname>;
		$:;
		<varname> = <js expr>;

	then to:
		var <varname>;
		$:
		<varname> = <js expr>;

- converts
		<==
			<code>

	to:
		`$:{`
		<code>
		`}`

	then to:
		$:{;
		<js code>
		};

	then to:
		$:{
		<js code>
		}

###

# ===========================================================================

export class StarbucksPreMapper extends SmartInput

	mapString: (line, level) ->

		debug "enter mapString(#{OL(line)})"
		if (line == '<==')
			# --- Generate a reactive block
			code = @fetchBlock(level+1)    # might be empty
			if isEmpty(code)
				debug "return undef from mapString() - empty code block"
				return undef
			else
				result = """
						`$:{`
						#{code}
						`}`
						"""

		else if lMatches = line.match(///^
				([A-Za-z][A-Za-z0-9_]*)   # variable name
				\s*
				\< \= \=
				\s*
				(.*)
				$///)
			[_, varname, expr] = lMatches
			code = @fetchBlock(level+1)    # must be empty
			assert isEmpty(code),
					"mapString(): indented code not allowed after '#{line}'"
			assert ! isEmpty(expr),
					"mapString(): empty expression in '#{line}'"
			result = """
					`$:`
					#{varname} = #{expr}
					"""
		else
			debug "return from mapString() - no match"
			return line

		debug "return from mapString()", result
		return result

# ---------------------------------------------------------------------------

export preProcessCoffee = (code) ->
	# --- Removes blank lines and comments
	#     inteprets <== as svelte reactive statement or block

	assert (indentLevel(code)==0), "preProcessCoffee(): has indentation"

	oInput = new StarbucksPreMapper(code)
	newcode = oInput.getAllText()
	debug 'newcode', newcode
	return newcode

# ---------------------------------------------------------------------------

export class StarbucksPostMapper extends StringInput
	# --- variable declaration immediately following one of:
	#        $:{;
	#        $:;
	#     should be moved above this line

	mapLine: (line, level) ->

		# --- new properties, initially undef:
		#        @savedLevel
		#        @savedLine

		if @savedLine
			if line.match(///^ \s* var \s ///)
				result = "#{line}\n#{@savedLine}"
			else
				result = "#{@savedLine}\n#{line}"
			@savedLine = undef
			return result

		if (lMatches = line.match(///^
				\$ \:
				(\{)?       # optional {
				\;
				(.*)        # any remaining text
				$///))
			[_, brace, rest] = lMatches
			assert ! rest, "StarbucksPostMapper: extra text after $:"
			@savedLevel = level
			if brace
				@savedLine = "$:{"
			else
				@savedLine = "$:"
			return undef
		else if (lMatches = line.match(///^
				\}
				\;
				(.*)
				$///))
			[_, rest] = lMatches
			assert ! rest, "StarbucksPostMapper: extra text after $:"
			return indented("\}", level)
		else
			return indented(line, level)

# ---------------------------------------------------------------------------

export postProcessCoffee = (code) ->
	# --- variable declaration immediately following one of:
	#        $:{
	#        $:
	#     should be moved above this line

	oInput = new StarbucksPostMapper(code)
	return oInput.getAllText()

# ---------------------------------------------------------------------------

export buildImportList = (lNeededSymbols) ->

	hLibs = {}   # { <lib>: [<symbol>, ... ], ... }
	lImports = []
	hAvailSymbols = getAvailSymbols()   # { <sym>: {lib: <lib>, src: <name> }}
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
	return lImports

# ---------------------------------------------------------------------------

export buildImportBlock = (lNeededSymbols) ->

	return buildImportList(lNeededSymbols).join("\n")

# ---------------------------------------------------------------------------

export getNeededSymbols = (code, hOptions={}) ->
	# --- Valid options:
	#        dumpfile: <filepath>   - where to dump ast
	#     NOTE: array returned will always be unique

	assert isString(code), "getNeededSymbols(): code must be a string"
	debug "enter getNeededSymbols()"
	try
		debug "COMPILE CODE", code
		ast = CoffeeScript.compile code, {ast: true}
		assert ast?, "getNeededSymbols(): ast is empty"
	catch err
		croak err, 'CODE (in getNeededSymbols)', code

	walker = new ASTWalker(ast)
	hSymbolInfo = walker.getSymbols()
	if hOptions.dumpfile
		barf hOptions.dumpfile, "AST:\n" + tamlStringify(ast)
	debug "return from getNeededSymbols()"
	return uniq(hSymbolInfo.lNeeded)

# ---------------------------------------------------------------------------
# export to allow unit testing

export getAvailSymbols = () ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>, default: true},...}

	debug "enter getAvailSymbols()"
	dir = process.env.DIR_ROOT
	if ! dir
		debug "return from getAvailSymbols() - env var DIR_ROOT not set"
		return {}
	debug "search for .symbols from '#{dir}'"
	filepath = pathTo('.symbols', dir, 'up')
	if ! filepath?
		debug "return from getAvailSymbols() - no .symbols file found"
		return {}

	hSymbols = getAvailSymbolsFrom(filepath)
	debug "hSymbols", hSymbols
	debug "return from getAvailSymbols()"
	return hSymbols

# ---------------------------------------------------------------------------

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

getAvailSymbolsFrom = (filepath) ->
	# --- returns { <symbol> -> {lib: <lib>, src: <name>}, ... }

	debug "enter getAvailSymbolsFrom('#{filepath}')"

	contents = slurp(filepath)
	debug 'Contents of .symbols', contents
	parser = new SymbolParser(contents)
	hSymbols = parser.getSymbols()
	debug "hSymbols", hSymbols
	debug "return from getAvailSymbolsFrom()"

	return hSymbols
