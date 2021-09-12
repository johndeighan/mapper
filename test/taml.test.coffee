# taml.test.coffee

import {undef, setUnitTesting} from '@jdeighan/coffee-utils'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {isTAML, taml, tamlStringify} from '@jdeighan/string-input/taml'

setUnitTesting(true)
simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.truthy 12, isTAML("---\n- first\n- second")
simple.falsy  13, isTAML("x---\n")
simple.equal  14, taml("---\n- a\n- b"), ['a','b']
simple.equal  15, tamlStringify({a:1, b:2}), """
		---
		a: 1
		b: 2
		"""
simple.equal  20, tamlStringify([1,'abc',{a:1}]), """
		---
		- 1
		- abc
		-
			a: 1
		"""
