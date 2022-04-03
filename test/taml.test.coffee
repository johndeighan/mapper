# taml.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {log, tamlStringify} from '@jdeighan/coffee-utils/log'
import {undented} from '@jdeighan/coffee-utils/indent'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'

import {Mapper} from '@jdeighan/mapper'
import {
	addHereDocType, mapHereDoc, lineToParts,
	} from '@jdeighan/mapper/heredoc'
import {
	isTAML, taml, slurpTAML, StoryMapper, TAMLHereDoc,
	} from '@jdeighan/mapper/taml'

addHereDocType new TAMLHereDoc()
simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.truthy 18, isTAML("---\n- first\n- second")
simple.falsy 19, isTAML("x---\n")

simple.equal 21, taml("""
		---
		- a
		- b
		"""), ['a','b']
simple.equal 26, taml("""
		---
		first: 42
		second: 13
		"""), {first:42, second:13}
simple.equal 31, taml("""
		---
		first: 1st
		second: 2nd
		"""), {first: '1st', second: '2nd'}

simple.equal 37, tamlStringify({a:1, b:2}), """
		---
		a: 1
		b: 2
		"""
simple.equal 42, tamlStringify([1,'abc',{a:1}]), """
		---
		- 1
		- abc
		-
			a: 1
		"""

simple.equal 50, slurpTAML('./test/data_structure.taml'), [
	'abc'
	42
	{first: '1st', second: '2nd'}
	]

# --- Test providing a premapper

simple.equal 58, taml("""
		---
		first: "Hi", Sally said
		second: "Hello to you", Mike said
		""", {premapper: StoryMapper}), {
			first: '"Hi", Sally said'
			second: '"Hello to you", Mike said'
			}

# ---------------------------------------------------------------------------

class HereDocTester extends UnitTesterNoNorm

	transformValue: (block) ->
		return mapHereDoc(block).str

tester = new HereDocTester()

# ---------------------------------------------------------------------------
# TAML block

tester.equal 70, """
		---
		- abc
		- def
		""",
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML-like block, but actually a block

tester.equal 80, """
		===
		---
		- abc
		- def
		""",
		'"---\\n- abc\\n- def"'

# ---------------------------------------------------------------------------
# TAML block 2

tester.equal 91, """
		---
		-
			label: Help
			url: /help
		-
			label: Books
			url: /books
		""",
		'[{"label":"Help","url":"/help"},{"label":"Books","url":"/books"}]'

# ---------------------------------------------------------------------------

class HereDocReplacer extends UnitTesterNoNorm

	transformValue: (block) ->
		lNewParts = for part in lineToParts(firstLine(block))
			if part == '<<<'
				mapHereDoc(undented(remainingLines(block))).str
			else
				part    # keep as is

		result = lNewParts.join('')
		return result

replacer = new HereDocReplacer()

# ---------------------------------------------------------------------------

replacer.equal 104, """
		TopMenu lItems={<<<}
			---
			-
				label: Help
				url: /help
			-
				label: Books
				url: /books
		""", """
		TopMenu lItems={[{"label":"Help","url":"/help"},{"label":"Books","url":"/books"}]}
		"""

# ---------------------------------------------------------------------------

replacer.equal 119, """
		<TopMenu lItems={<<<}>
			---
			-
				label: Help
				url: /help
			-
				label: Books
				url: /books
		""", """
		<TopMenu lItems={[{"label":"Help","url":"/help"},{"label":"Books","url":"/books"}]}>
		"""
