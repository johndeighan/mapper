# symbols.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {log} from '@jdeighan/coffee-utils/log'
import {
	getNeededSymbols, buildImportBlock, addImports,
	} from '@jdeighan/string-input/symbols'

simple = new UnitTester()
rootDir = mydir(import.meta.url)

# ---------------------------------------------------------------------------

simple.equal 16, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

simple.equal 21, getNeededSymbols("""
	x = 23
	y = x + 5
	"""), []

simple.equal 26, getNeededSymbols("""
	x = z
	y = x + 5
	"""), ['z']

simple.equal 31, getNeededSymbols("""
	x = myfunc(4)
	y = x + 5
	"""), ['myfunc']

simple.equal 36, getNeededSymbols("""
	import {z} from 'somewhere'
	x = z
	y = x + 5
	"""), []

simple.equal 42, getNeededSymbols("""
	import {myfunc} from 'somewhere'
	x = myfunc(4)
	y = x + 5
	"""), []

# ---------------------------------------------------------------------------

class ImportTester extends UnitTesterNoNorm

	transformValue: (code) ->
		return addImports(code, rootDir)

tester = new ImportTester()

# ---------------------------------------------------------------------------

# --- Contents of .symbols:
# fs
# 	*fs exists readFile
#
# @jdeighan/coffee-utils
# 	say undef
#
# @jdeighan/coffee-utils/fs
# 	mydir mkpath slurp barf
#
# @jdeighan/coffee-utils/log
# 	log (as logger)

tester.equal 61, """
		x = undef
		""",
	"""
		import {undef} from '@jdeighan/coffee-utils'
		x = undef
		"""

tester.equal 69, """
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

tester.equal 82, """
		x = 23
		logger x
		""",
	"""
		import {log as logger} from '@jdeighan/coffee-utils/log'
		x = 23
		logger x
		"""
