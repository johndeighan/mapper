# cielo.coffee

import {assert, say, isString, isArray} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {indentLevel} from '@jdeighan/coffee-utils/indent'
import {
	withExt, newerDestFileExists, slurp, shortenPath,
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
		# --- keep comments
		return line

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

checkCieloHash = (hCielo, maxBlocks=1) ->

	assert hCielo?, "checkCieloHash(): empty hCielo"
	assert 'code' in hCielo, "checkCieloHash(): No key 'code'"
	assert (hCielo.code.length <= maxBlocks), "checkCieloHash(): Too many blocks"
	assert isString(hCielo.code[0]), "checkCieloHash(): code[0] not a string"
	if 'importStmts' in hCielo
		assert isArray(hCielo.importStmts), "checkCieloHash(): 'importStmts' not an array"
	return

# ---------------------------------------------------------------------------

buildCieloBlock = (hCielo) ->

	checkCieloHash(hCielo)
	code = hCielo.code[0]
	lImportStmts = hCielo.importStmts
	if ('importStmts' in hCielo) && (hCielo.importStmts.length > 0)
		return hCielo.importStmt.join("\n") + "\n" + code
	else
		return code

# ---------------------------------------------------------------------------

brewCieloStr = (str) ->
	# --- cielo => coffee

	hCielo = brewCielo(str)
	return buildCieloBlock(hCielo)

# ---------------------------------------------------------------------------

export output = (code, srcPath, destPath, doLog=false) ->

	try
		barf destPath, code
	catch err
		log "output(): ERROR: #{err.message}"
	if doLog
		log "   => #{shortenPath(destPath)}"
	return

# ---------------------------------------------------------------------------

brewCieloFile = (srcPath) ->
	# --- cielo => coffee

	destPath = withExt(srcPath, '.coffee')
	if ! newerDestFileExists(srcPath, destPath)
		str = slurp(srcPath)
		code = brewCieloStr(str)
		output code, srcPath, destPath, quiet
	return

