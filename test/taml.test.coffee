# taml.test.coffee

import {log, undef, setUnitTesting} from '@jdeighan/coffee-utils'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {isTAML, taml} from '@jdeighan/string-input/convert'

setUnitTesting(true)
simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.truthy 34, isTAML("---\n- first\n- second")
simple.falsy  35, isTAML("x---\n")
simple.equal  36, taml("---\n- a\n- b"), ['a','b']
