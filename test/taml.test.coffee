# taml.test.coffee

import {AvaTester} from '@jdeighan/ava-tester'
import {say, undef, setUnitTesting} from '@jdeighan/coffee-utils'
import {isTAML, taml} from '@jdeighan/string-input/convert'

setUnitTesting(true)
simple = new AvaTester()

# ---------------------------------------------------------------------------

simple.truthy 34, isTAML("---\n- first\n- second")
simple.falsy  35, isTAML("x---\n")
simple.equal  36, taml("---\n- a\n- b"), ['a','b']

# ---------------------------------------------------------------------------
# test taml() for creating a function

(() ->

	func = taml("""
			--- function
			() -> return "apple"
			""")
	simple.equal 117, func(), "apple"
	)()
