# cielo.coffee

import {
	assert, say, isString, isArray, isEmpty, nonEmpty, isHash,
	undef, OL, uniq, rtrim,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {log} from '@jdeighan/coffee-utils/log'
import {indentLevel} from '@jdeighan/coffee-utils/indent'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	withExt, newerDestFileExists, slurp, barf, shortenPath, mydir,
	} from '@jdeighan/coffee-utils/fs'
import {SmartInput} from '@jdeighan/string-input'
import {
	getNeededSymbols, buildImportList,
	} from '@jdeighan/string-input/symbols'

rootDir = process.env.DIR_ROOT = mydir(`import.meta.url`)

# ---------------------------------------------------------------------------
# --- Features:
#        1. REMOVE blank lines
#        2. REMOVE comments
#        3. #include <file>
#        4. handle <== (blocks and statements)
#        5. replace {{FILE}}, {{LINE}} and {{DIR}}
#        6. handle continuation lines
#        7. handle HEREDOC
#        8. stop on __END__
#        9. add auto-imports

# ---------------------------------------------------------------------------

export brewCielo = (lBlocks, hOptions={}) ->
	# --- convert blocks of cielo code to blocks of coffee code
	#     also provides needed import statements

	debug "enter brewCielo()"

	lAllNeededSymbols = []
	lNewBlocks = for code,i in lBlocks
		assert (indentLevel(code)==0), "brewCielo(): code #{i} has indent"

		# --- CieloMapper handles the above conversions
		if hOptions.source
			oInput = new CieloMapper(code, hOptions.source)
		else
			oInput = new CieloMapper(code)
		coffeeCode = oInput.getAllText()

		lNeededSymbols = getNeededSymbols(coffeeCode)
		lAllNeededSymbols = lAllNeededSymbols.concat(lNeededSymbols)

		debug 'CIELO CODE', code
		debug 'lNeededSymbols', lNeededSymbols
		debug 'COFFEE CODE', coffeeCode

		coffeeCode    # add to lNewBlocks

	importStmts = buildImportList(lAllNeededSymbols, rootDir).join("\n")
	debug 'importStmts', importStmts

	debug "return from brewCielo()"
	return {
		code: lNewBlocks
		lAllNeededSymbols: uniq(lAllNeededSymbols)
		importStmts
		}

# ---------------------------------------------------------------------------

export brewCieloStr = (lBlocks, hOptions={}) ->
	# --- cielo => coffee
	#     Valid options:
	#        source - the source, e.g. file full path

	hCielo = brewCielo(lBlocks, hOptions)
	checkCieloHash(hCielo)
	return joinBlocks(hCielo.importStmts, hCielo.code...)

# ---------------------------------------------------------------------------

class CieloMapper extends SmartInput

	mapString: (line, level) ->

		debug "enter mapString(#{OL(line)})"
		if (line == '<==')
			# --- Generate a reactive block
			code = rtrim(@fetchBlock(level+1))   # might be empty
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
			assert nonEmpty(expr),
					"mapString(): empty expression in '#{line}'"

			# --- Alternatively, we could prepend "<varname> = undefined"
			#     to this???
			result = """
					`$:{`
					#{line.replace('<==', '=')}
					`}`
					"""
		else
			debug "return from mapString() - no match"
			return line

		debug "return from mapString()", result
		return result

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
