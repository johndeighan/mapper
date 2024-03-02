# Symbols.test.coffee

import {undef, OL, words, isEmpty} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {UnitTester, equal} from '@jdeighan/base-utils/utest'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {
	getAvailSymbols, getAvailSymbolsFrom,
	getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'

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

hSymbols = {
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

equal getAvailSymbolsFrom("./test/.symbols"), hSymbols
equal getAvailSymbols(import.meta.url), hSymbols

# ---------------------------------------------------------------------------

class SymbolsTester extends UnitTester

	transformValue: (text) ->
		return getNeededSymbols(text)

symTester = new SymbolsTester()

# ---------------------------------------------------------------------------

equal getNeededSymbols("""
	name = 'John'
	"""), []

equal getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

equal getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

equal getNeededSymbols("""
	x = z
	y = x + 5
	"""), ['z']

equal getNeededSymbols("""
	x = myfunc(4)
	y = x + 5
	"""), ['myfunc']

equal getNeededSymbols("""
	import {z} from 'somewhere'
	x = z
	y = x + 5
	"""), []

equal getNeededSymbols("""
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
equal hSymbols, {
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

	equal joinBlocks(lImports..., text), """
			import {say} from '@jdeighan/coffee-utils'
			import {slurp} from '#jdeighan/base-utils/fs'
			x = 42
			say "Answer is 42"
			"""
	)()

# ----------------------------------------------------------------------------

(() ->
	equal buildImportList([]), {lNotFound: [], lImportStmts: []}

	lMissing = words('say undef logger slurp barf fs')
	equal buildImportList(lMissing, import.meta.url), {
		lNotFound: []
		lImportStmts: [
			"import fs from 'fs'"
			"import {slurp,barf} from '@jdeighan/base-utils/fs'"
			"import {say,undef} from '@jdeighan/coffee-utils'"
			"import {log as logger} from '@jdeighan/coffee-utils/log'"
			],
		}

	)()
