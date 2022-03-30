# FuncHereDoc.coffee

import {
	undef, isArray,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {DEBUG} from '@jdeighan/coffee-utils/log'
import {
	indented, undented,
	} from '@jdeighan/coffee-utils/indent'

import {coffeeCodeToJS} from '@jdeighan/string-input/coffee'

# ---------------------------------------------------------------------------
# --- This class, or a subclass, can be used
#     with addHereDocType

export class FuncHereDoc

	myName: () ->
		return 'function'

	isMyHereDoc: (block) ->
		return isFunctionDef(block)

	# --- treat strBody as CoffeeScript
	#     These 2 methods should return JavaScript code

	codeToFuncStr: (lParms, strBody) ->
		coffeeCode = buildCoffeeCode(lParms, strBody)
		return coffeeCodeToJS(coffeeCode)

	codeToFunc: (lParms, strBody) ->
		strBody = coffeeCodeToJS(strBody)
		return new Function(lParms..., strBody)

	map: (block, lParts=undef) ->
		debug "enter FuncHereDoc.map()"

		# --- lParts should be return value from isMyHereDoc()
		#     if empty, we'll just call it again
		if lParts
			[lParms, strBody] = lParts
		else
			[lParms, strBody] = @isMyHereDoc(block)

		hResult = {
			str: @codeToFuncStr(lParms, strBody)
			obj: @codeToFunc(lParms, strBody)
			}
		debug "return from FuncHereDoc.map()", hResult
		return hResult

# ---------------------------------------------------------------------------

isFunctionDef = (block) ->

	debug "enter isFunctionDef()", block
	lMatches = block.match(///^
			\(
			\s*
			(                            # optional parameters
				[A-Za-z_][A-Za-z0-9_]*
				(?:
					,
					\s*
					[A-Za-z_][A-Za-z0-9_]*
					)*
				)?
			\s*
			\)
			\s*
			->
			[\ \t]*
			\n?
			(.*)
			$///s)
	if ! lMatches
		debug "return from isFunctionDef - no match"
		return undef
	[_, strParms, strBody] = lMatches
	if strBody?
		strBody = undented(strBody)
	else
		strBody = ''

	# --- Remove whitespace, then split on commas
	if strParms?
		lParms = strParms.replace(/\s+/g, '').split(',')
	else
		lParms = []
	lParts = [lParms, strBody]
	debug "return from isFunctionDef()", lParts
	return lParts

# ---------------------------------------------------------------------------

export buildCoffeeCode = (lParms, strBody) ->

	if lParms && isArray(lParms) && (lParms.length > 0)
		coffeeCode = "(#{lParms.join(',')}) ->"
	else
		coffeeCode = "() ->"
	if strBody
		coffeeCode = coffeeCode + "\n" + indented(strBody, 1)
	return coffeeCode

# ---------------------------------------------------------------------------

export buildJSCode = (lParms, strBody) ->

	if lParms && isArray(lParms) && (lParms.length > 0)
		jsCode = "(#{lParms.join(',')}) ->"
	else
		jsCode = "() =>"
	if strBody
		jsCode = jsCode + "\n" + indented(strBody, 1)
	return jsCode
