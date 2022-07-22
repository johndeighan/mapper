# taml.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {log, tamlStringify} from '@jdeighan/coffee-utils/log'
import {undented} from '@jdeighan/coffee-utils/indent'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'

import {Mapper} from '@jdeighan/mapper'
import {
	isTAML, taml, slurpTAML,
	} from '@jdeighan/mapper/taml'

simple = new UnitTesterNorm()

# ---------------------------------------------------------------------------

simple.truthy 23, isTAML("---\n- first\n- second")
simple.falsy 24, isTAML("x---\n")

simple.equal 26, taml("""
		---
		- a
		- b
		"""), ['a','b']
simple.equal 31, taml("""
		---
		first: 42
		second: 13
		"""), {first:42, second:13}
simple.equal 36, taml("""
		---
		first: 1st
		second: 2nd
		"""), {first: '1st', second: '2nd'}

simple.equal 42, tamlStringify({a:1, b:2}), """
		---
		a: 1
		b: 2
		"""
simple.equal 47, tamlStringify([1,'abc',{a:1}]), """
		---
		- 1
		- abc
		-
			a: 1
		"""

simple.equal 55, slurpTAML('./test/data_structure.taml'), [
	'abc'
	42
	{first: '1st', second: '2nd'}
	]

# --- Test providing a premapper

class StoryMapper extends Mapper

	map: (hLine) ->

		{line, level} = hLine
		if lMatches = line.match(///
				([A-Za-z_][A-Za-z0-9_]*)  # identifier
				\:                        # colon
				\s*                       # optional whitespace
				(.+)                      # a non-empty string
				$///)
			[_, ident, str] = lMatches

			if str.match(///
					\d+
					(?:
						\.
						\d*
						)?
					$///)
				return line
			else
				# --- surround with single quotes, double internal single quotes
				str = "'" + str.replace(/\'/g, "''") + "'"
				return "#{ident}: #{str}"
		else
			return line

simple.equal 89, taml("""
		---
		first: "Hi", Sally said
		second: "Hello to you", Mike said
		""", {premapper: StoryMapper, source: import.meta.url}), {
			first: '"Hi", Sally said'
			second: '"Hello to you", Mike said'
			}
