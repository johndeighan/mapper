# sass.test.coffee

import {undef} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {UnitTesterNorm} from '@jdeighan/unit-tester'
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
