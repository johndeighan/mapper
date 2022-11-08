# sass.test.coffee

import {assert, croak, setDebugging} from '@jdeighan/base-utils'
import {UnitTesterNorm} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {sassify} from '@jdeighan/mapper/sass'

# ---------------------------------------------------------------------------

class SassTester extends UnitTesterNorm

	transformValue: (text) ->

		return sassify(text)

sassTester = new SassTester()

# ---------------------------------------------------------------------------

(() ->

	sassTester.equal 50, """
		# --- a comment
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
