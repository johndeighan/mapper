# coffee.coffee

import CoffeeScript from 'coffeescript'

import {
	CWS, undef, defined, OL, getOptions,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE, sep_dash} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {mkpath, slurp, barf} from '@jdeighan/base-utils/fs'
import {
	indentLevel, isUndented, indented,
	} from '@jdeighan/coffee-utils/indent'

import {Mapper, map} from '@jdeighan/mapper'
import {TreeMapper} from '@jdeighan/mapper/tree'

projRoot = mkpath('c:', 'Users', 'johnd', 'mapper')

# ---------------------------------------------------------------------------

export brew = (code) ->

	hCoffeeOptions = {
		bare: true
		header: false
		}
	mapped = map(code, CoffeePreProcessor)
	result = CoffeeScript.compile(mapped, hCoffeeOptions)

	# --- Result is JS code
	return result.trim()

# ---------------------------------------------------------------------------

export coffeeCodeToJS = (coffeeCode) ->

	assert isUndented(coffeeCode), "has indentation"
	dbgEnter "coffeeCodeToJS", coffeeCode

	try
		jsCode = brew(coffeeCode)

		# --- cleanJS() does:
		#        1. remove blank lines
		#        2. remove trailing newline
		jsCode = cleanJS(jsCode)
	catch err
		croak err, "Original Code", coffeeCode

	dbgReturn "coffeeCodeToJS", jsCode
	return jsCode

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

export coffeeFileToJS = (srcPath, destPath=undef, hOptions={}) ->
	# --- coffee => js
	#     Valid Options:
	#        saveAST
	#        force
	#        premapper
	#        postmapper

	if notdefined(destPath)
		destPath = withExt(srcPath, '.js')
	{force, saveAST} = getOptions(hOptions)
	if force || ! newerDestFileExists(srcPath, destPath)
		coffeeCode = slurp(srcPath)
		if saveAST
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
		jsCode = coffeeCodeToJS(coffeeCode)
		barf jsCode, destPath
	return

# ---------------------------------------------------------------------------

export coffeeCodeToAST = (coffeeCode) ->

	assert isUndented(coffeeCode), "has indentation"
	dbgEnter "coffeeCodeToAST", coffeeCode
	barf coffeeCode, projRoot, 'test', 'ast.coffee'

	try
		mapped = map(coffeeCode, CoffeePreProcessor)
		assert defined(mapped), "mapped is undef"
		barf mapped, projRoot, 'test', 'ast.cielo'
	catch err
		barf coffeeCode, projRoot, 'test', 'ast.coffee'
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
		dbgEnter "CoffeePreProcessor.mapComment"
		{str, level} = hNode
		result = indented(str, level, @oneIndent)
		dbgReturn "CoffeePreProcessor.mapComment", result
		return result

	# ..........................................................

	getUserObj: (hNode) ->
		# --- only non-special nodes

		dbgEnter "CoffeePreProcessor.getUserObj", hNode
		{str, level} = hNode
		result = str.replace(///
				\"
				[^"]*     # sequence of non-quote characters
				\"
				///g,
			(qstr) -> expand(qstr)
			)
		result = indented(result, level, @oneIndent)
		dbgReturn "CoffeePreProcessor.getUserObj", result
		return result
