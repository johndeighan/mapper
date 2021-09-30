# auto-import.test.coffee

import {strict as assert} from 'assert'

import {undef, words, isArray} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	buildImportList, getAvailSymbols, brewCielo,
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
	lNeeded = words('say undef log slurp barf')
	simple.equal 58, buildImportList(lNeeded), [
		"import {say,undef} from '@jdeighan/coffee-utils'",
		"import {slurp,barf} from '@jdeighan/coffee-utils/fs'",
		"import {log} from '@jdeighan/coffee-utils/log'",
		]
	)()

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

class CieloTester extends UnitTester

	transformValue: (code) ->

		return brewCielo(code)

export cieloTester = new CieloTester()

# ---------------------------------------------------------------------------

cieloTester.equal 149, """
		import {undef, pass} from '@jdeighan/coffee-utils'
		import {slurp, barf} from '@jdeighan/coffee-utils/fs'

		try
			contents = slurp('myfile.txt')
		if (contents == undef)
			print "File does not exist"
		""", """
		import {undef, pass} from '@jdeighan/coffee-utils'
		import {slurp, barf} from '@jdeighan/coffee-utils/fs'

		try
			contents = slurp('myfile.txt')
		if (contents == undef)
			print "File does not exist"
		"""
