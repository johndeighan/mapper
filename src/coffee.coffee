# coffee.coffee

import CoffeeScript from 'coffeescript'

import {LOG, LOGVALUE, assert, croak} from '@jdeighan/exceptions'
import {dbg, dbgEnter, dbgReturn} from '@jdeighan/exceptions/debug'
import {
	CWS, undef, defined, OL, sep_dash,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, isUndented, indented,
	} from '@jdeighan/coffee-utils/indent'
import {mkpath, barf} from '@jdeighan/coffee-utils/fs'

import {Mapper, map} from '@jdeighan/mapper'
import {TreeMapper} from '@jdeighan/mapper/tree'

projRoot = mkpath('c:', 'Users', 'johnd', 'mapper')

# ---------------------------------------------------------------------------

export brew = (code, source='internal') ->

	hCoffeeOptions = {
		bare: true
		header: false
		}
	mapped = map(source, code, CoffeePreProcessor)
	result = CoffeeScript.compile(mapped, hCoffeeOptions)

	# --- Result is JS code
	return result.trim()

# ---------------------------------------------------------------------------

export coffeeExprToJS = (coffeeExpr) ->

	assert isUndented(coffeeExpr), "has indentation"
	dbgEnter "coffeeExprToJS"

	try
		jsExpr = brew(coffeeExpr)

		# --- Remove any trailing semicolon
		pos = jsExpr.length - 1
		if jsExpr.substr(pos, 1) == ';'
			jsExpr = jsExpr.substr(0, pos)

	catch err
		croak err, "coffeeExprToJS", coffeeExpr

	dbgReturn "coffeeExprToJS", jsExpr
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
	dbgEnter "coffeeCodeToJS", coffeeCode, source, hOptions

	try
		jsCode = brew(coffeeCode, source)

		# --- cleanJS() does:
		#        1. remove blank lines
		#        2. remove trailing newline
		jsCode = cleanJS(jsCode)
	catch err
		croak err, "Original Code", coffeeCode

	dbgReturn "coffeeCodeToJS", jsCode
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
				dbg "NO NEEDED SYMBOLS in #{shortenPath(destPath)}:"
			else
				n = lNeeded.length
				word = if (n==1) then'SYMBOL' else 'SYMBOLS'
				dbg "#{n} NEEDED #{word} in #{shortenPath(destPath)}:"
				for sym in lNeeded
					dbg "   - #{sym}"
		jsCode = coffeeCodeToJS(coffeeCode, srcPath, hOptions)
		barf destPath, jsCode
	return

# ---------------------------------------------------------------------------

export coffeeCodeToAST = (coffeeCode, source=undef) ->

	assert isUndented(coffeeCode), "has indentation"
	dbgEnter "coffeeCodeToAST", coffeeCode, source
	barf mkpath(projRoot, 'test', 'ast.coffee'), coffeeCode

	try
		mapped = map(source, coffeeCode, CoffeePreProcessor)
		assert defined(mapped), "mapped is undef"
		barf mkpath(projRoot, 'test', 'ast.cielo'), mapped
	catch err
		barf mkpath(projRoot, 'test', 'ast.coffee'), coffeeCode
		croak "ERROR in CoffeePreProcessor: #{err.message}"

	try
		ast = CoffeeScript.compile(mapped, {ast: true})
		assert defined(ast), "ast is empty"
	catch err
		LOG "ERROR in CoffeeScript: #{err.message}"
		LOG sep_dash
		LOG "#{OL(coffeeCode)}"
		LOG sep_dash
		croak "ERROR in CoffeeScript: #{err.message}"

	dbgReturn "coffeeCodeToAST", ast
	return ast

# ---------------------------------------------------------------------------

export cleanJS = (jsCode) ->

	jsCode = jsCode.replace(/\n\n+/gs, "\n") # multiple NL to single NL
	jsCode = jsCode.replace(/\n$/s, '')      # strip trailing whitespace
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

export class CoffeePreProcessor extends TreeMapper

	mapComment: (hNode) ->

		# --- Retain comments
		dbgEnter "mapComment"
		{str, level} = hNode
		result = indented(str, level, @oneIndent)
		dbgReturn "mapComment", result
		return result

	# ..........................................................

	mapNode: (hNode) ->
		# --- only non-special nodes

		dbgEnter "mapNode", hNode
		{str, level} = hNode
		result = str.replace(///
				\"
				[^"]*     # sequence of non-quote characters
				\"
				///g,
			(qstr) -> expand(qstr)
			)
		result = indented(result, level, @oneIndent)
		dbgReturn "mapNode", result
		return result
