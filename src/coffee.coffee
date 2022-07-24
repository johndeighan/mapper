# coffee.coffee

import CoffeeScript from 'coffeescript'

import {
	assert, croak, CWS, undef, defined, OL,
	} from '@jdeighan/coffee-utils'
import {log, LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'
import {indentLevel, isUndented} from '@jdeighan/coffee-utils/indent'

import {Mapper, doMap} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

export brew = (code, source='internal') ->

	hCoffeeOptions = {
		bare: true
		header: false
		}
	mapped = doMap(CoffeePreProcessor, source, code)
	result = CoffeeScript.compile(mapped, hCoffeeOptions)

	# --- Result is JS code
	return result.trim()

# ---------------------------------------------------------------------------

export getAST = (code, source='internal') ->

	hCoffeeOptions = {
		ast: true
		}
	mapped = doMap(CoffeePreProcessor, source, code)
	result = CoffeeScript.compile(mapped, hCoffeeOptions)

	# --- Result is an AST
	return result

# ---------------------------------------------------------------------------

export coffeeExprToJS = (coffeeExpr) ->

	assert isUndented(coffeeExpr), "has indentation"
	debug "enter coffeeExprToJS()"

	try
		jsExpr = brew(coffeeExpr)

		# --- Remove any trailing semicolon
		pos = jsExpr.length - 1
		if jsExpr.substr(pos, 1) == ';'
			jsExpr = jsExpr.substr(0, pos)

	catch err
		croak err, "coffeeExprToJS", coffeeExpr

	debug "return from coffeeExprToJS()", jsExpr
	return jsExpr

# ---------------------------------------------------------------------------
# --- Available options in hOptions:
#        bare: boolean   - compile without top-level function wrapper
#        header: boolean - include "Generated by CoffeeScript" comment
#        ast: boolean - include AST in return value
#        transpile - options object to use with Babel
#        sourceMap - generate a source map
#        filename - name of the source map file
#        inlineMap - generate source map inside the JS file
# ---------------------------------------------------------------------------

export coffeeCodeToJS = (coffeeCode, source=undef, hOptions={}) ->

	assert isUndented(coffeeCode), "has indentation"
	debug "enter coffeeCodeToJS()", coffeeCode

	try
		jsCode = brew(coffeeCode, source)

		# --- cleanJS() does:
		#        1. remove blank lines
		#        2. remove trailing newline
		jsCode = cleanJS(jsCode)
	catch err
		croak err, "Original Code", coffeeCode

	debug "return from coffeeCodeToJS()", jsCode
	return jsCode

# ---------------------------------------------------------------------------

export coffeeFileToJS = (srcPath, destPath=undef, hOptions={}) ->
	# --- coffee => js
	#     Valid Options:
	#        saveAST
	#        force
	#        premapper
	#        postmapper

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
		jsCode = coffeeCodeToJS(coffeeCode, srcPath, hOptions)
		barf destPath, jsCode
	return

# ---------------------------------------------------------------------------

export coffeeCodeToAST = (coffeeCode, source=undef) ->

	assert isUndented(coffeeCode), "has indentation"
	debug "enter coffeeCodeToAST()", coffeeCode

	try
		ast = getAST(coffeeCode, source)
		assert ast?, "ast is empty"
	catch err
		croak err, "in coffeeCodeToAST", coffeeCode

	debug "return from coffeeCodeToAST()", ast
	return ast

# ---------------------------------------------------------------------------

export cleanJS = (jsCode) ->

	jsCode = jsCode.replace(/\n\n+/gs, "\n")
	jsCode = jsCode.replace(/\n$/s, '')
	return jsCode

# ---------------------------------------------------------------------------

export minifyJS = (jsCode, lParms) ->

	jsCode = CWS(jsCode)
	jsCode = jsCode.replace(/,\s+/, ',')
	return jsCode

# ---------------------------------------------------------------------------

expand = (qstr) ->

	lMatches = qstr.match(/^\"(.*)\"$/)
	assert defined(lMatches), "Bad arg: #{OL(qstr)}"
	assert (lMatches[1].indexOf('"') == -1), "Bad arg: #{OL(qstr)}"
	result = qstr.replace(///
			\$
			([A-Za-z_][A-Za-z0-9_]*)
			///g,
		(_, ident) -> "\#{OL(#{ident})}"
		)

# ---------------------------------------------------------------------------

export class CoffeePreProcessor extends Mapper

	mapComment: (hLine) ->
		# --- Retain comments

		return hLine.line

	# ..........................................................

	map: (hLine) ->

		result = hLine.line.replace(///
				\"
				[^"]*     # sequence of non-quote characters
				\"
				///g,
			(qstr) -> expand(qstr)
			)
		return result

