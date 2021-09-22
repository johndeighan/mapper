# auto-import.test.coffee

import {strict as assert} from 'assert'

import {undef, words} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	mergeNeededSymbols, getNeededSymbols, buildImportList, getNeededImports,
	getMissingSymbols, getAvailSymbols,
	} from '@jdeighan/string-input/coffee'

testDir = mydir(`import.meta.url`)
process.env.DIR_SYMBOLS = testDir
simple = new UnitTester()
dumpfile = "c:/Users/johnd/string-input/test/ast.txt"

# ----------------------------------------------------------------------------
# --- make sure it's using the testing .symbols file

hSymbols = getAvailSymbols()
simple.equal 23, hSymbols, {
		barf:   '@jdeighan/coffee-utils/fs',
		log:    '@jdeighan/coffee-utils/log',
		mkpath: '@jdeighan/coffee-utils/fs',
		mydir:  '@jdeighan/coffee-utils/fs',
		say:    '@jdeighan/coffee-utils',
		slurp:  '@jdeighan/coffee-utils/fs',
		undef:  '@jdeighan/coffee-utils',
		}

# ----------------------------------------------------------------------------

(() ->
	text = """
			x = 42
			say "Answer is 42"
			"""

	lImports = [
		"import {say} from '@jdeighan/coffee-utils'",
		"import {slurp} from '#jdeighan/coffee-utils/fs'",
		]

	simple.equal 46, joinBlocks(lImports..., text), """
			import {say} from '@jdeighan/coffee-utils'
			import {slurp} from '#jdeighan/coffee-utils/fs'
			x = 42
			say "Answer is 42"
			"""
	)()

# ----------------------------------------------------------------------------

(() ->
	hAllNeeded = {}
	hNeeded = {
		'@jdeighan/coffee-utils': ['say', 'undef'],
		'@jdeighan/coffee-utils/log': ['log'],
		}
	mergeNeededSymbols(hAllNeeded, hNeeded)
	simple.equal 63, hAllNeeded, {
		'@jdeighan/coffee-utils': ['say', 'undef']
		'@jdeighan/coffee-utils/log': ['log']
		}
	)()

# ----------------------------------------------------------------------------

(() ->
	hAllNeeded = {
		'@jdeighan/coffee-utils': ['say'],
		'@jdeighan/coffee-utils/fs': ['slurp'],
		}
	hNeeded = {
		'@jdeighan/coffee-utils': ['undef', 'say'],
		'@jdeighan/coffee-utils/log': ['log'],
		'@jdeighan/coffee-utils/fs': ['barf'],
		}
	mergeNeededSymbols(hAllNeeded, hNeeded)
	simple.equal 82, hAllNeeded, {
		'@jdeighan/coffee-utils': ['say', 'undef'],
		'@jdeighan/coffee-utils/log': ['log'],
		'@jdeighan/coffee-utils/fs': ['slurp', 'barf'],
		}
	)()

# ----------------------------------------------------------------------------

(() ->
	hAllNeeded = {
		'@jdeighan/coffee-utils': ['say', 'undef'],
		'@jdeighan/coffee-utils/log': ['log'],
		'@jdeighan/coffee-utils/fs': ['slurp', 'barf'],
		}
	simple.equal 97, buildImportList(hAllNeeded), [
		"import {say,undef} from '@jdeighan/coffee-utils'",
		"import {slurp,barf} from '@jdeighan/coffee-utils/fs'",
		"import {log} from '@jdeighan/coffee-utils/log'",
		]
	)()

# ----------------------------------------------------------------------------

(() ->
	code = """
			say "Hi, there!"
			for list in lLists
				barf "myfile.txt", list
			"""
	lImports = getNeededImports(code)
	simple.equal 113, lImports, [
		"import {say} from '@jdeighan/coffee-utils'",
		"import {barf} from '@jdeighan/coffee-utils/fs'",
		]
	)()

# ----------------------------------------------------------------------------

(() ->
	code = """
			say "Hi, there!"
			for list in lLists
				barf "myfile.txt", list
			"""
	hMissingSymbols = getMissingSymbols(code)
	simple.equal 128, hMissingSymbols, {
		say: {}
		lLists: {}
		barf: {}
		}
	)()
