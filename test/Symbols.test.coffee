# Symbols.test.coffee

import {undef, OL, words, isEmpty} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {
	UnitTesterNorm, UnitTester, utest,
	} from '@jdeighan/unit-tester'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {
	getAvailSymbols, getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'

dumpfile = "c:/Users/johnd/string-input/test/ast.txt"

# ---------------------------------------------------------------------------
# Contents of .symbols:
# fs
# 	*fs exists readFile
#
# @jdeighan/base-utils/fs
# 	mkpath slurp barf
#
# @jdeighan/coffee-utils
# 	say undef
#
# @jdeighan/coffee-utils/fs
# 	mydir
#
# @jdeighan/coffee-utils/log
# 	log/logger

utest.equal 36, getAvailSymbols(import.meta.url), {
	barf: {
		lib: '@jdeighan/base-utils/fs',
		},
	exists: {
		lib: 'fs',
		},
	fs: {
		isDefault: true,
		lib: 'fs',
		},
	logger: {
		lib: '@jdeighan/coffee-utils/log',
		src: 'log',
		},
	mkpath: {
		lib: '@jdeighan/base-utils/fs',
		},
	mydir: {
		lib: '@jdeighan/coffee-utils/fs',
		},
	readFile: {
		lib: 'fs',
		},
	say: {
		lib: '@jdeighan/coffee-utils',
		},
	slurp: {
		lib: '@jdeighan/base-utils/fs',
		},
	undef: {
		lib: '@jdeighan/coffee-utils',
		},
	}

# ---------------------------------------------------------------------------

class SymbolsTester extends UnitTester

	transformValue: (text) ->
		return getNeededSymbols(text)

symTester = new SymbolsTester()

# ---------------------------------------------------------------------------

utest.equal 82, getNeededSymbols("""
	name = 'John'
	"""), []

utest.equal 86, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

utest.equal 91, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

utest.equal 96, getNeededSymbols("""
	x = z
	y = x + 5
	"""), ['z']

utest.equal 101, getNeededSymbols("""
	x = myfunc(4)
	y = x + 5
	"""), ['myfunc']

utest.equal 106, getNeededSymbols("""
	import {z} from 'somewhere'
	x = z
	y = x + 5
	"""), []

utest.equal 112, getNeededSymbols("""
	import {myfunc} from 'somewhere'
	x = myfunc(4)
	y = x + 5
	"""), []

# ---------------------------------------------------------------------------
#    Test auto-import
# ---------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# --- make sure it's using the testing .symbols file

hSymbols = getAvailSymbols(import.meta.url)
utest.equal 126, hSymbols, {
		fs:      {lib: 'fs', isDefault: true}
		exists:  {lib: 'fs'}
		readFile:{lib: 'fs'}
		barf:    {lib: '@jdeighan/base-utils/fs'}
		logger:  {lib: '@jdeighan/coffee-utils/log', src: 'log'}
		mkpath:  {lib: '@jdeighan/base-utils/fs'}
		mydir:   {lib: '@jdeighan/coffee-utils/fs'}
		say:     {lib: '@jdeighan/coffee-utils'}
		slurp:   {lib: '@jdeighan/base-utils/fs'}
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
		"import {slurp} from '#jdeighan/base-utils/fs'",
		]

	utest.equal 152, joinBlocks(lImports..., text), """
			import {say} from '@jdeighan/coffee-utils'
			import {slurp} from '#jdeighan/base-utils/fs'
			x = 42
			say "Answer is 42"
			"""
	)()

# ----------------------------------------------------------------------------

(() ->
	utest.equal 163, buildImportList([]), {lImports: [], lNotFound: []}

	lMissing = words('say undef logger slurp barf fs')
	utest.equal 166, buildImportList(lMissing, import.meta.url), {
		lImports: [
			"import fs from 'fs'"
			"import {slurp,barf} from '@jdeighan/base-utils/fs'"
			"import {say,undef} from '@jdeighan/coffee-utils'"
			"import {log as logger} from '@jdeighan/coffee-utils/log'"
			],
		lNotFound: []
		}

	)()
