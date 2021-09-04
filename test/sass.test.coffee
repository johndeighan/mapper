# sass.test.coffee

import {say, undef, setUnitTesting} from '@jdeighan/coffee-utils'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {sassify} from '@jdeighan/string-input/convert'

root = process.env.dir_root = mydir(`import.meta.url`)
process.env.dir_data = "#{root}/data
process.env.dir_markdown = "#{root}/markdown
simple = new UnitTester()
setUnitTesting(true)

# ---------------------------------------------------------------------------

class SassTester extends UnitTester

	transformValue: (text) ->

		return sassify(text)

tester = new SassTester()

# ---------------------------------------------------------------------------

(() ->

	tester.equal 30, """
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

setUnitTesting false

(() ->

	tester.equal 51, """
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
