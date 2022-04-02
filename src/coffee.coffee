# coffee.coffee

import CoffeeScript from 'coffeescript'

import {
	assert, croak, CWS, undef,
	} from '@jdeighan/coffee-utils'
import {log, LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'
import {indentLevel} from '@jdeighan/coffee-utils/indent'

export convertingCoffee = true

# ---------------------------------------------------------------------------

export convertCoffee = (flag) ->

	convertingCoffee = flag
	return

# ---------------------------------------------------------------------------

export coffeeExprToJS = (coffeeExpr) ->

	assert (indentLevel(coffeeExpr)==0), "coffeeExprToJS(): has indentation"
	debug "enter coffeeExprToJS()"

	if ! convertingCoffee
		debug "return from coffeeExprToJS() not converting", coffeeExpr
		return coffeeExpr
	try
		jsExpr = CoffeeScript.compile(coffeeExpr, {bare: true}).trim()

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

export coffeeCodeToJS = (coffeeCode, hOptions={}) ->

	assert (indentLevel(coffeeCode)==0), "coffeeCodeToJS(): has indentation"
	debug "enter coffeeCodeToJS()"

	if ! convertingCoffee
		debug "return from coffeeCodeToJS() not converting", coffeeCode
		return coffeeCode

	hCoffeeOptions = hOptions.hCoffeeOptions
	if ! hCoffeeOptions
		hCoffeeOptions = {
			bare: true
			header: false
			}
	try
		# --- cleanJS() does:
		#        1. remove blank lines
		#        2. remove trailing newline
		jsCode = cleanJS(CoffeeScript.compile(coffeeCode, hCoffeeOptions))
	catch err
		croak err, "Original Code", coffeeCode

	debug "return from coffeeCodeToJS()", jsCode
	return jsCode

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
