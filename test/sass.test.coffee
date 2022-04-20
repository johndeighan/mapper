# sass.test.coffee

import {UnitTesterNorm} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {sassify, convertSASS} from '@jdeighan/mapper/sass'

simple = new UnitTesterNorm()

convertSASS false

# ---------------------------------------------------------------------------

class SassTester extends UnitTesterNorm

	transformValue: (text) ->
		return sassify(text, import.meta.url)

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
