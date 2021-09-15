# sass.test.coffee

import {undef} from '@jdeighan/coffee-utils'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {sassify, convertSASS} from '@jdeighan/string-input/sass'

root = process.env.dir_root = mydir(`import.meta.url`)
process.env.dir_data = "#{root}/data
process.env.dir_markdown = "#{root}/markdown
simple = new UnitTester()

convertSASS false

# ---------------------------------------------------------------------------

class SassTester extends UnitTester

	transformValue: (text) ->
		return sassify(text)

tester = new SassTester()

# ---------------------------------------------------------------------------

(() ->
	tester.equal 28, """
	# --- This is a red paragraph (this should be removed)
	p
		margin: 0
		span
			# --- this is also a comment
			color: red
	""", """
	p
		margin: 0
		span
			color: red
	"""

	)()

# ---------------------------------------------------------------------------

convertSASS true

(() ->

	tester.equal 50, """
	# --- here, we should use the real sass processor
	p
		margin: 0
		span
			color: red
	""", """
	p {
		margin: 0;
	}
	p span {
		color: red;
	}
	"""
	)()

# ---------------------------------------------------------------------------
