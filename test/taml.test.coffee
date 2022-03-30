# taml.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {log, tamlStringify} from '@jdeighan/coffee-utils/log'
import {isTAML, taml, slurpTAML} from '@jdeighan/string-input/taml'

simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.truthy 12, isTAML("---\n- first\n- second")
simple.falsy 13, isTAML("x---\n")

simple.equal 15, taml("""
		---
		- a
		- b
		"""), ['a','b']
simple.equal 20, taml("""
		---
		first: 42
		second: 13
		"""), {first:42, second:13}
simple.equal 25, taml("""
		---
		first: 1st
		second: 2nd
		"""), {first: '1st', second: '2nd'}

simple.equal 31, tamlStringify({a:1, b:2}), """
		---
		a: 1
		b: 2
		"""
simple.equal 36, tamlStringify([1,'abc',{a:1}]), """
		---
		- 1
		- abc
		-
			a: 1
		"""

simple.equal 44, slurpTAML('./test/data_structure.taml'), [
	'abc'
	42
	{first: '1st', second: '2nd'}
	]

simple.equal 50, taml("""
		---
		first: "Hi", Sally said
		second: "Hello to you", Mike said
		"""), {
			first: '"Hi", Sally said'
			second: '"Hello to you", Mike said'
			}

