# coffee.coffee

import CoffeeScript from 'coffeescript'

import {
	assert, croak, OL, isString, isEmpty, undef
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {debug} from '@jdeighan/coffee-utils/debug'
import {
	withExt, slurp, barf, newerDestFileExists, shortenPath,
	} from '@jdeighan/coffee-utils/fs'
import {indentLevel, indented} from '@jdeighan/coffee-utils/indent'
import {StringInput, SmartInput} from '@jdeighan/string-input'
import {
	getNeededSymbols, buildImportBlock, addImports,
	} from '@jdeighan/string-input/symbols'

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

export brewCoffeeStr = (code, hOptions={}) ->
	# --- coffee => js
	#     Valid Options:
	#        saveAST
	#        force

	assert isString(code), "brewCoffeeStr(): code is not a string"
	lBlocks = preBrewCoffee(code)
	newcode = joinBlocks(lBlocks...)

	debug 'CODE', code
	debug 'NEW CODE', newcode

	return newcode

# ---------------------------------------------------------------------------

export brewCoffeeFile = (srcPath, destPath=undef, hOptions={}) ->
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
	importBlock = buildImportBlock(lNeededSymbols, process.env.DIR_ROOT)
	debug "return from preBrewCoffee()"
	return [importBlock, lNewBlocks...]

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
