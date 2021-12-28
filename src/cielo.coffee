# cielo.coffee

import {
	assert, say, isString, isArray, isHash, undef,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {log} from '@jdeighan/coffee-utils/log'
import {indentLevel} from '@jdeighan/coffee-utils/indent'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	withExt, newerDestFileExists, slurp, barf, shortenPath,
	} from '@jdeighan/coffee-utils/fs'
import {SmartInput} from '@jdeighan/string-input'
import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/string-input/coffee'

# ---------------------------------------------------------------------------

class CieloMapper extends SmartInput
	# --- retain empty lines & comments

	handleEmptyLine: (level) ->
		# --- keep empty lines
		return ''

	handleComment: (line, level) ->
		# --- keep comments, unless they start with '### '
		return if line.match(/^\s*###\s/) then undef else line

# ---------------------------------------------------------------------------
# --- Features:
#        1. KEEP blank lines and comments
#        2. #include <file>
#        3. replace {{FILE}} and {{LINE}}
#        4. handle continuation lines
#        5. handle HEREDOC
#        6. stop on __END__
#        7. add auto-imports

export brewCielo = (lBlocks...) ->
	# --- convert blocks of cielo code to blocks of coffee code
	#     also provides needed import statements

	debug "enter brewCielo()"

	lAllNeededSymbols = []
	lNewBlocks = []
	for code,i in lBlocks
		assert (indentLevel(code)==0), "brewCielo(): code #{i} has indent"

		# --- CieloMapper handles the above conversions
		oInput = new CieloMapper(code)
		coffeeCode = oInput.getAllText()

		# --- will be unique
		lNeededSymbols = getNeededSymbols(coffeeCode)
		for symbol in lNeededSymbols
			if ! lAllNeededSymbols.includes(symbol)
				lAllNeededSymbols.push symbol

		lNewBlocks.push coffeeCode

		debug 'CIELO CODE', code
		debug 'lNeededSymbols', lNeededSymbols
		debug 'COFFEE CODE', coffeeCode

	importStmts = buildImportList(lAllNeededSymbols).join("\n")
	debug 'importStmts', importStmts

	debug "return from brewCielo()"
	return {
		code: lNewBlocks
		lAllNeededSymbols
		importStmts
		}

# ---------------------------------------------------------------------------

export checkCieloHash = (hCielo, maxBlocks=1) ->

	assert hCielo?, "checkCieloHash(): empty hCielo"
	assert isHash(hCielo), "checkCieloHash(): hCielo is not a hash"
	assert hCielo.hasOwnProperty('code'), "checkCieloHash(): No key 'code'"
	assert (hCielo.code.length <= maxBlocks), "checkCieloHash(): Too many blocks"
	assert isString(hCielo.code[0]), "checkCieloHash(): code[0] not a string"
	if hCielo.hasOwnProperty('importStmts')
		assert isString(hCielo.importStmts), "checkCieloHash(): 'importStmts' not a string"
	return

# ---------------------------------------------------------------------------

export buildCieloBlock = (hCielo) ->

	checkCieloHash(hCielo)
	return joinBlocks(hCielo.importStmts, hCielo.code[0])

# ---------------------------------------------------------------------------

export brewCieloStr = (code) ->
	# --- cielo => coffee

	hCielo = brewCielo(code)
	return buildCieloBlock(hCielo)

# ---------------------------------------------------------------------------

export brewCieloFile = (srcPath, destPath=undef, hOptions={}) ->
	# --- cielo => coffee
	#     Valid Options:
	#        force

	if ! destPath?
		destPath = withExt(srcPath, '.coffee')
	if hOptions.force || ! newerDestFileExists(srcPath, destPath)
		cieloCode = slurp(srcPath)
		coffeeCode = brewCieloStr(cieloCode)
		barf destPath, coffeeCode
	return
