# auto-import.test.coffee

import assert from 'assert'

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {undef, words, isArray} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {log} from '@jdeighan/coffee-utils/log'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {
	cieloCodeToJS, addImports, convertCielo,
	} from '@jdeighan/mapper/cielo'
import {
	setSymbolsRootDir, buildImportList, getAvailSymbols,
	} from '@jdeighan/mapper/symbols'

setSymbolsRootDir mydir(`import.meta.url`)
simple = new UnitTester()
dumpfile = "c:/Users/johnd/string-input/test/ast.txt"
convertCielo false

# ----------------------------------------------------------------------------
# --- make sure it's using the testing .symbols file

hSymbols = getAvailSymbols()
simple.equal 27, hSymbols, {
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

	simple.equal 53, joinBlocks(lImports..., text), """
			import {say} from '@jdeighan/coffee-utils'
			import {slurp} from '#jdeighan/coffee-utils/fs'
			x = 42
			say "Answer is 42"
			"""
	)()

# ----------------------------------------------------------------------------

(() ->
	lNeeded = words('say undef logger slurp barf fs')
	simple.equal 65, buildImportList(lNeeded), [
		"import fs from 'fs'"
		"import {say,undef} from '@jdeighan/coffee-utils'"
		"import {slurp,barf} from '@jdeighan/coffee-utils/fs'"
		"import {log as logger} from '@jdeighan/coffee-utils/log'"
		]
	)()

# ----------------------------------------------------------------------------

(() ->
	code = """
			# --- temp.cielo
			if fs.existsSync('file.txt')
				logger "file exists"
			"""

	jsCode = cieloCodeToJS(code)

	simple.equal 85, jsCode, """
			import fs from 'fs'
			import {log as logger} from '@jdeighan/coffee-utils/log'
			# --- temp.cielo
			if fs.existsSync('file.txt')
				logger "file exists"
			"""
	)()

# ---------------------------------------------------------------------------

(() ->

	class CieloTester extends UnitTesterNoNorm

		transformValue: (text) ->
			return cieloCodeToJS(text)

	tester = new CieloTester('cielo.test')

	# --- Should auto-import mydir & mkpath from @jdeighan/coffee-utils/fs

	tester.equal 108, """
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			import {mydir,mkpath} from '@jdeighan/coffee-utils/fs'
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			"""

	# --- But not if we're already importing them

	tester.equal 119, """
			import {mkpath,mydir} from '@jdeighan/coffee-utils/fs'
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			import {mkpath,mydir} from '@jdeighan/coffee-utils/fs'
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			"""

	tester.equal 114, """
			x = undef
			""",
		"""
			import {undef} from '@jdeighan/coffee-utils'
			x = undef
			"""

	tester.equal 122, """
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

	tester.equal 135, """
			x = 23
			logger x
			""",
		"""
			import {log as logger} from '@jdeighan/coffee-utils/log'
			x = 23
			logger x
			"""

	)()
