# utils.test.coffee

import {strict as assert} from 'assert'

import {
	undef, log, setUnitTesting, words,
	} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {startDebugging, endDebugging} from '@jdeighan/coffee-utils/debug'
import {
	mergeNeededSymbols, getNeededSymbols, buildImportList, getNeededImports,
	getMissingSymbols, getAvailSymbols, prependImports,
	} from '@jdeighan/string-input/code'

testDir = mydir(`import.meta.url`)
process.env.DIR_SYMBOLS = testDir
simple = new UnitTester()
dumpfile = "c:/Users/johnd/string-input/test/ast.txt"
setUnitTesting true

# ----------------------------------------------------------------------------
# --- make sure it's using the testing .symbols file

hSymbols = getAvailSymbols()
simple.equal 25, hSymbols, {
		barf:   '@jdeighan/coffee-utils/fs',
		log:    '@jdeighan/coffee-utils',
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

	simple.equal 38, prependImports(text, lImports), """
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
		'@jdeighan/coffee-utils': ['say', 'log', 'undef']
		}
	mergeNeededSymbols(hAllNeeded, hNeeded)
	simple.equal 29, hAllNeeded, {
			'@jdeighan/coffee-utils': ['say', 'log', 'undef']
			}
	)()

# ----------------------------------------------------------------------------

(() ->
	hAllNeeded = {
		'@jdeighan/coffee-utils': ['say'],
		'@jdeighan/coffee-utils/fs': ['slurp'],
		}
	hNeeded = {
		'@jdeighan/coffee-utils': ['log', 'undef', 'say'],
		'@jdeighan/coffee-utils/fs': ['barf'],
		}
	mergeNeededSymbols(hAllNeeded, hNeeded)
	simple.equal 29, hAllNeeded, {
		'@jdeighan/coffee-utils': ['say', 'log', 'undef'],
		'@jdeighan/coffee-utils/fs': ['slurp', 'barf'],
		}
	)()

# ----------------------------------------------------------------------------

(() ->
	hAllNeeded = {
		'@jdeighan/coffee-utils': ['say', 'log', 'undef'],
		'@jdeighan/coffee-utils/fs': ['slurp', 'barf'],
		}
	simple.equal 68, buildImportList(hAllNeeded), [
		"import {say,log,undef} from '@jdeighan/coffee-utils'",
		"import {slurp,barf} from '@jdeighan/coffee-utils/fs'",
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
	simple.equal 88, lImports, [
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
	simple.equal 88, hMissingSymbols, {
			say: {}
			lLists: {}
			barf: {}
			}
	)()
