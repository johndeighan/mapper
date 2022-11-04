# Symbols.test.coffee

import {LOG, assert, croak, setDebugging} from '@jdeighan/base-utils'
import {UnitTesterNorm, UnitTester, utest} from '@jdeighan/unit-tester'
import {undef, OL, words, isEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {
	getAvailSymbols, getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'

dumpfile = "c:/Users/johnd/string-input/test/ast.txt"

# ---------------------------------------------------------------------------
# Contents of .symbols:
# fs
#    *fs exists readFile
#
# @jdeighan/coffee-utils
#    say undef
#
# @jdeighan/coffee-utils/fs
#    mydir mkpath slurp barf
#
# @jdeighan/coffee-utils/log
#    log/logger

utest.equal 31, getAvailSymbols(import.meta.url), {
	barf: {
		lib: '@jdeighan/coffee-utils/fs',
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
		lib: '@jdeighan/coffee-utils/fs',
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
		lib: '@jdeighan/coffee-utils/fs',
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

utest.equal 77, getNeededSymbols("""
	name = 'John'
	"""), []

utest.equal 81, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

utest.equal 86, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

utest.equal 91, getNeededSymbols("""
	x = z
	y = x + 5
	"""), ['z']

utest.equal 96, getNeededSymbols("""
	x = myfunc(4)
	y = x + 5
	"""), ['myfunc']

utest.equal 101, getNeededSymbols("""
	import {z} from 'somewhere'
	x = z
	y = x + 5
	"""), []

utest.equal 107, getNeededSymbols("""
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
utest.equal 121, hSymbols, {
		fs:      {lib: 'fs', isDefault: true}
		exists:  {lib: 'fs'}
		readFile:{lib: 'fs'}
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

	utest.equal 147, joinBlocks(lImports..., text), """
			import {say} from '@jdeighan/coffee-utils'
			import {slurp} from '#jdeighan/coffee-utils/fs'
			x = 42
			say "Answer is 42"
			"""
	)()

# ----------------------------------------------------------------------------

(() ->
	utest.equal 158, buildImportList([]), []

	lMissing = words('say undef logger slurp barf fs')
	utest.equal 161, buildImportList(lMissing, import.meta.url), [
		"import fs from 'fs'"
		"import {say,undef} from '@jdeighan/coffee-utils'"
		"import {slurp,barf} from '@jdeighan/coffee-utils/fs'"
		"import {log as logger} from '@jdeighan/coffee-utils/log'"
		]

	)()
