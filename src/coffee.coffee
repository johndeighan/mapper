# coffee.coffee

import {strict as assert} from 'assert'
import CoffeeScript from 'coffeescript'

import {
	croak, OL, escapeStr,
	isEmpty, nonEmpty, words, undef, deepCopy,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {debug} from '@jdeighan/coffee-utils/debug'
import {mydir, pathTo, slurp, barf} from '@jdeighan/coffee-utils/fs'
import {indentLevel, indented} from '@jdeighan/coffee-utils/indent'
import {StringInput, SmartInput} from '@jdeighan/string-input'
import {ASTWalker} from '@jdeighan/string-input/tree'
import {tamlStringify} from '@jdeighan/string-input/taml'

convert = true

# ---------------------------------------------------------------------------
# --- Features:
#        1. KEEP blank lines and comments
#        2. #include <file>
#        3. replace {{FILE}} and {{LINE}}
#        4. handle continuation lines
#        5. handle HEREDOC
#        6. add auto-imports

export brewCielo = (code) ->

	debug "enter brewCielo()"
	assert (indentLevel(code)==0), "brewCielo(): code has indentation"

	oInput = new CieloMapper(code)
	newcode = oInput.getAllText()

	# --- returns {<lib>: [<symbol>,... ],... }
	hNeeded = getNeededSymbols(newcode)

	if isEmpty(hNeeded)
		debug "return from brewCielo() - no needed symbols"
		return newcode
	else
		lImports = buildImportList(hNeeded)
		result = joinBlocks(lImports..., newcode)
		debug "return #{OL(result)} from brewCielo()"
		return result

# ---------------------------------------------------------------------------

export class CieloMapper extends SmartInput
	# --- retain empty lines & comments

	handleEmptyLine: (level) ->
		return ''

	handleComment: (line, level) ->
		return line

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export convertCoffee = (flag) ->

	convert = flag
	return

# ---------------------------------------------------------------------------

export brewExpr = (expr, force=false) ->

	assert (indentLevel(expr)==0), "brewExpr(): has indentation"

	if not convert && not force
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

	hAllNeeded = {}    # { <lib>: [ <symbol>, ...], ...}
	lNewBlocks = for blk,i in lBlocks
		debug "BLOCK #{i}", blk
		newblk = preProcessCoffee(blk)
		debug "NEW BLOCK", newblk

		# --- returns {<lib>: [<symbol>,... ],... }
		hNeeded = getNeededSymbols(newblk)
		mergeNeededSymbols(hAllNeeded, hNeeded)

		if not convert
			newblk
		else
			try
				script = CoffeeScript.compile(newblk, {bare: true})
				debug "BREWED SCRIPT", script
				postProcessCoffee(script)
			catch err
				log "Mapped Text:", newblk
				croak err, "Original Text", blk

	# --- return converted blocks, PLUS the list of needed imports
	return [lNewBlocks..., buildImportList(hAllNeeded)]

# ---------------------------------------------------------------------------

export brewCoffee = (code) ->

	[newcode, lImports] = preBrewCoffee(code)
	return joinBlocks(lImports..., newcode)
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
			assert not isEmpty(expr),
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
			assert not rest, "StarbucksPostMapper: extra text after $:"
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
			assert not rest, "StarbucksPostMapper: extra text after $:"
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

			@getAll()
			return @hSymbols

	contents = slurp(filepath)
	debug 'Contents of .symbols', contents
	parser = new SymbolParser(contents)
	hSymbols = parser.getSymbols()
	debug "hSymbols", hSymbols
	debug "return from getAvailSymbols()"
	return hSymbols
