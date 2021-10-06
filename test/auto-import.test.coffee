# auto-import.test.coffee

import {strict as assert} from 'assert'

import {undef, words, isArray} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	buildImportList, getAvailSymbols,
	} from '@jdeighan/string-input/coffee'

testDir = mydir(`import.meta.url`)
process.env.DIR_SYMBOLS = testDir
simple = new UnitTester()
dumpfile = "c:/Users/johnd/string-input/test/ast.txt"

# ----------------------------------------------------------------------------
# --- make sure it's using the testing .symbols file

hSymbols = getAvailSymbols()
simple.equal 23, hSymbols, {
		barf:    {lib: '@jdeighan/coffee-utils/fs'}
		logger:  {lib: '@jdeighan/coffee-utils/log', src: 'log'}
		mkpath:  {lib: '@jdeighan/coffee-utils/fs'}
		mydir:   {lib: '@jdeighan/coffee-utils/fs'}
		say:     {lib: '@jdeighan/coffee-utils'}
		slurp:   {lib: '@jdeighan/coffee-utils/fs'}
		undef:   {lib: '@jdeighan/coffee-utils'}
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
	lNeeded = words('say undef logger slurp barf')
	simple.equal 58, buildImportList(lNeeded), [
		"import {say,undef} from '@jdeighan/coffee-utils'",
		"import {slurp,barf} from '@jdeighan/coffee-utils/fs'",
		"import {log as logger} from '@jdeighan/coffee-utils/log'",
		]
	)()

# ---------------------------------------------------------------------------
