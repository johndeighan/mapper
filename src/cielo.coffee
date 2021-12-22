# cielo.coffee

import {assert, say} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {indentLevel} from '@jdeighan/coffee-utils/indent'
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
