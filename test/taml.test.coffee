# taml.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {undef, rtrim} from '@jdeighan/coffee-utils'
import {log, tamlStringify} from '@jdeighan/coffee-utils/log'
import {undented, tabify} from '@jdeighan/coffee-utils/indent'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'

import {Mapper} from '@jdeighan/mapper'
import {isTAML, taml, slurpTAML} from '@jdeighan/mapper/taml'

# ---------------------------------------------------------------------------

simple.truthy 14, isTAML("---\n- first\n- second")
simple.falsy 15, isTAML("x---\n")

# ---------------------------------------------------------------------------

(() ->
	class TamlTester extends UnitTester

		transformValue: (block) ->
			return taml(block)

	tester = new TamlTester()

	# ---------------------------------------------------------------------------

	tester.equal 29, """
			---
			- a
			- b
		""",
		['a','b']

	tester.equal 36, """
			---
			first: 42
			second: 13
			""",
			{first:42, second:13}

	tester.equal 43, """
			---
			first: 1st
			second: 2nd
			""",
			{first: '1st', second: '2nd'}
	)()

# ---------------------------------------------------------------------------

(() ->
	class StringifyTester extends UnitTester

		transformValue: (ds) ->
			# --- tamlStringify() produces text with a single space char
			#     for each level of indentation
			return tabify(rtrim(tamlStringify(ds)), 1)

	tester = new StringifyTester()

	# ---------------------------------------------------------------------------

	tester.equal 63, {a:1, b:2}, """
			---
			a: 1
			b: 2
			"""

	tester.equal 69, [1, 'abc', {a:1}], """
			---
			- 1
			- abc
			-
				a: 1
			"""
	)()

# ---------------------------------------------------------------------------

simple.equal 80, slurpTAML('./test/data_structure.taml'), [
	'abc'
	42
	{first: '1st', second: '2nd'}
	]

# ---------------------------------------------------------------------------
# --- Test providing a premapper

class StoryMapper extends Mapper

	mapNonSpecial: (hLine) ->

		if lMatches = hLine.str.match(///
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
				return str
			else
				# --- surround with single quotes, double internal single quotes
				str = "'" + str.replace(/\'/g, "''") + "'"
				return "#{ident}: #{str}"
		else
			return hLine.str

simple.equal 116, taml("""
		---
		first: "Hi", Sally said
		second: "Hello to you", Mike said
		""", {premapper: StoryMapper, source: import.meta.url}), {
			first: '"Hi", Sally said'
			second: '"Hello to you", Mike said'
			}
