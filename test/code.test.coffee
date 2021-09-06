# code.test.coffee

import {strict as assert} from 'assert'

import {
	undef, say, isString, isHash, isEmpty, nonEmpty, setUnitTesting,
	arrayToString, escapeStr, sep_dash, sep_eq,
	} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {
	forEachLine, forEachBlock, forEachSetOfBlocks,
	} from '@jdeighan/coffee-utils/block'
import {
	getMissingSymbols, getNeededImports, getAvailSymbols,
	} from '@jdeighan/string-input/code'

testDir = mydir(`import.meta.url`)
filepath = mkpath(testDir, 'code.test.txt')
simple = new UnitTester()
dumpfile = "c:/Users/johnd/string-input/test/ast.txt"

# ----------------------------------------------------------------------------

(() ->
	lTests = []

	callback = (lBlocks, lineNum) ->
		[src, expImports] = lBlocks
		if src
			if lMatches = src.match(///^
						\*        # an asterisk
						(\*?)     # possible 2nd asterisk
						\s*       # skip any whitespace
						(.*)      # capture the real source string
						$///s)
				[doDebug, src] = lMatches
				if doDebug
					lTests.push [-(100000 + lineNum), src, expImports]
				else
					lTests.push [-lineNum, src, expImports]
			else
				lTests.push [lineNum, lBlocks...]
		return

	await forEachSetOfBlocks filepath, callback

	for [lineNum, src, expImports] in lTests
		hOptions = {}
		if (lineNum < 0)
			hOptions.dumpfile = dumpfile

		simple.equal lineNum, getNeededImports(src, hOptions), expImports

		# --- embed the code in an IIFE
		src = """
			(() ->
			#{indented(src, 1)}
				)()
			"""
		simple.equal lineNum, getNeededImports(src), expImports

	)()

# ----------------------------------------------------------------------------
