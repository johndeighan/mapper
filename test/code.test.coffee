# code.test.coffee

import {strict as assert} from 'assert'

import {
	undef, say, isString, isHash, isEmpty, nonEmpty, setUnitTesting,
	arrayToString, escapeStr,
	} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {
	forEachLine, forEachBlock, forEachSetOfBlocks,
	} from '@jdeighan/coffee-utils/block'
import {
	getMissingSymbols, getNeededImports, getAvailSymbols,
	} from '@jdeighan/string-input/code'

testDir = mydir(`import.meta.url`)
filepath = mkpath(testDir, 'code.test.txt')
simple = new UnitTester()

# ----------------------------------------------------------------------------

(() ->
	lTests = []

	callback = (lBlocks, lineNum) ->
		[src, expImports, expMissing] = lBlocks
		if src
			if lMatches = src.match(///^
						\*          # an asterisk
						[\*\s]*     # skip any following asterisks or whitespace
						(.*)        # capture the real source string
						$///s)
				src = lMatches[1]
				lTests.push [-lineNum, src, expImports, expMissing]
			else
				lTests.push [lineNum, lBlocks...]
		return

	await forEachSetOfBlocks filepath, callback

	for [lineNum, src, expImports, expMissing] in lTests
		[lImports, lMissing] = getNeededImports(src)
		simple.equal lineNum, lImports.join('\n'), expImports
		simple.equal lineNum, lMissing.join('\n'), expMissing

	)()

# ----------------------------------------------------------------------------
