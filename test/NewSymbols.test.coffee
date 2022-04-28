# Symbols.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {undef, OL, words, isEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {log} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {
	getAvailSymbols, getNeededSymbols, buildImportList,
	} from '@jdeighan/mapper/symbols'
import {
	cieloCodeToJS, convertCielo,
	} from '@jdeighan/mapper/cielo'

simple = new UnitTesterNorm()
dumpfile = "c:/Users/johnd/string-input/test/ast.txt"
convertCielo false

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
#    log (as logger)

simple.equal 28, getAvailSymbols(import.meta.url), {
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

tester = new SymbolsTester()

# ---------------------------------------------------------------------------

simple.equal 74, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

simple.equal 79, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

simple.equal 84, getNeededSymbols("""
	x = z
	y = x + 5
	"""), ['z']

simple.equal 89, getNeededSymbols("""
	x = myfunc(4)
	y = x + 5
	"""), ['myfunc']

simple.equal 94, getNeededSymbols("""
	import {z} from 'somewhere'
	x = z
	y = x + 5
	"""), []

simple.equal 100, getNeededSymbols("""
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
simple.equal 114, hSymbols, {
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

	simple.equal 140, joinBlocks(lImports..., text), """
			import {say} from '@jdeighan/coffee-utils'
			import {slurp} from '#jdeighan/coffee-utils/fs'
			x = 42
			say "Answer is 42"
			"""
	)()

# ----------------------------------------------------------------------------

(() ->
	lNeeded = words('say undef logger slurp barf fs')
	simple.equal 152, buildImportList(lNeeded, import.meta.url), [
		"import fs from 'fs'"
		"import {say,undef} from '@jdeighan/coffee-utils'"
		"import {slurp,barf} from '@jdeighan/coffee-utils/fs'"
		"import {log as logger} from '@jdeighan/coffee-utils/log'"
		]
	)()

# ----------------------------------------------------------------------------

(() ->
	cieloCode = """
			# --- temp.cielo
			if fs.existsSync('file.txt')
				logger "file exists"
			"""

	{imports, jsCode} = cieloCodeToJS(cieloCode, import.meta.url)

	simple.equal 171, imports, """
			import fs from 'fs'
			import {log as logger} from '@jdeighan/coffee-utils/log'
			"""

	simple.equal 176, jsCode, """
			# --- temp.cielo
			if fs.existsSync('file.txt')
				logger "file exists"
			"""
	)()

# ---------------------------------------------------------------------------

(() ->

	class CieloTester extends UnitTester

		transformValue: (text) ->
			{imports, jsCode} = cieloCodeToJS(text, import.meta.url)
			if isEmpty(imports)
				return jsCode
			else
				return [imports, jsCode].join("\n")

	tester = new CieloTester('cielo.test')

	# --- Should auto-import mydir & mkpath from @jdeighan/coffee-utils/fs

	tester.equal 200, """
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			import {mydir,mkpath} from '@jdeighan/coffee-utils/fs'
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			"""

	# --- But not if we're already importing them

	tester.equal 211, """
			import {mkpath,mydir} from '@jdeighan/coffee-utils/fs'
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			import {mkpath,mydir} from '@jdeighan/coffee-utils/fs'
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			"""

	tester.equal 221, """
			x = undef
			""",
		"""
			import {undef} from '@jdeighan/coffee-utils'
			x = undef
			"""

	tester.equal 229, """
			x = undef
			contents = 'this is a file'
			fs.writeFileSync('temp.txt', contents, {encoding: 'utf8'})
			""",
		"""
			import fs from 'fs'
			import {undef} from '@jdeighan/coffee-utils'
			x = undef
			contents = 'this is a file'
			fs.writeFileSync('temp.txt', contents, {encoding: 'utf8'})
			"""

	tester.equal 242, """
			x = 23
			logger x
			""",
		"""
			import {log as logger} from '@jdeighan/coffee-utils/log'
			x = 23
			logger x
			"""

	)()