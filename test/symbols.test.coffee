# symbols.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {log} from '@jdeighan/coffee-utils/log'
import {
	setSymbolsRootDir, symbolsRootDir, getAvailSymbols, getNeededSymbols,
	addImports,
	} from '@jdeighan/string-input/symbols'

dir = mydir(import.meta.url)
setSymbolsRootDir dir
simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.equal 18, symbolsRootDir, dir

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

simple.equal 34, getAvailSymbols(), {
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

simple.equal 71, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

simple.equal 76, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

simple.equal 81, getNeededSymbols("""
	x = z
	y = x + 5
	"""), ['z']

simple.equal 86, getNeededSymbols("""
	x = myfunc(4)
	y = x + 5
	"""), ['myfunc']

simple.equal 91, getNeededSymbols("""
	import {z} from 'somewhere'
	x = z
	y = x + 5
	"""), []

simple.equal 97, getNeededSymbols("""
	import {myfunc} from 'somewhere'
	x = myfunc(4)
	y = x + 5
	"""), []

# ---------------------------------------------------------------------------

class ImportTester extends UnitTesterNoNorm

	transformValue: (code) ->
		return addImports(code)

tester = new ImportTester()

# ---------------------------------------------------------------------------

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
