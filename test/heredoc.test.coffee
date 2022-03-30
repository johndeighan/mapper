# heredoc.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {
	assert, undef, isString, extractMatches,
	} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {undented} from '@jdeighan/coffee-utils/indent'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'

import {
	lineToParts, mapHereDoc, addHereDocType,
	} from '@jdeighan/string-input/heredoc'

simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.equal 20, lineToParts('this <<< is <<< heredoc'), [
	'this '
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

simple.equal 28, lineToParts('<<< is <<< heredoc'), [
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

simple.equal 35, lineToParts('this <<< is <<<'), [
	'this '
	'<<<'
	' is '
	'<<<'
	]

simple.equal 42, lineToParts('<<< is <<<'), [
	'<<<'
	' is '
	'<<<'
	]

simple.equal 48, lineToParts('<<<'), [
	'<<<'
	]

simple.equal 52, lineToParts('<<<<<<'), [
	'<<<'
	'<<<'
	]

# ---------------------------------------------------------------------------

class HereDocTester extends UnitTesterNoNorm

	transformValue: (block) ->
		return mapHereDoc(block).str

tester = new HereDocTester()

# ---------------------------------------------------------------------------
# Default heredoc type is a block

tester.equal 69, """
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

tester.equal 78, """
		===
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# TAML block

tester.equal 88, """
		---
		- abc
		- def
		""",
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML-like block, but actually a block

tester.equal 98, """
		===
		---
		- abc
		- def
		""",
		'"---\\n- abc\\n- def"'

# ---------------------------------------------------------------------------
# TAML block 2

tester.equal 109, """
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
# One Line block

tester.equal 123, """
		...this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# One Line block

tester.equal 132, """
		...
		this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Test creating a new heredoc type

class MatrixHereDoc

	myName: () ->
		return 'matrix'

	isMyHereDoc: (block) ->
		# --- if block starts with a digit
		return block.match(/^\s*\d/)

	map: (block) ->
		lArray = []
		for line in blockToArray(block)
			lArray.push extractMatches(line, /\d+/g, parseInt)
		return {
			obj: lArray
			str: JSON.stringify(lArray)
			}

addHereDocType new MatrixHereDoc()

tester.equal 162, """
		1 2 3
		2 4 6
		""",
		'[[1,2,3],[2,4,6]]'

# ---------------------------------------------------------------------------
# Test creating a new heredoc type by overriding mapToString

class UCHereDoc

	myName: () ->
		return 'upper case'

	isMyHereDoc: (block) ->
		return block.indexOf('^^^') == 0

	map: (block) ->
		block = block.substring(4).toUpperCase()
		return {
			obj: block
			str: JSON.stringify(block)
			}

addHereDocType new UCHereDoc()

tester.equal 188, """
		^^^
		This is a
		block of text
		""",
		'"THIS IS A\\nBLOCK OF TEXT"'

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

replacer.equal 213, """
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

replacer.equal 228, """
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
