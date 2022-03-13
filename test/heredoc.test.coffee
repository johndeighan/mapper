# heredoc.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {assert, undef, extractMatches} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {log} from '@jdeighan/coffee-utils/log'
import {
	mapHereDoc, addHereDocType, BaseHereDoc, lineToParts, doDebug,
	} from '@jdeighan/string-input/heredoc'
import {undented} from '@jdeighan/coffee-utils/indent'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'

simple = new UnitTester()

# ---------------------------------------------------------------------------

simple.equal 15, lineToParts('this <<< is <<< heredoc'), [
	'this '
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]
simple.equal 22, lineToParts('<<< is <<< heredoc'), [
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]
simple.equal 28, lineToParts('this <<< is <<<'), [
	'this '
	'<<<'
	' is '
	'<<<'
	]
simple.equal 34, lineToParts('<<< is <<<'), [
	'<<<'
	' is '
	'<<<'
	]
simple.equal 39, lineToParts('<<<'), [
	'<<<'
	]
simple.equal 42, lineToParts('<<<<<<'), [
	'<<<'
	'<<<'
	]

# ---------------------------------------------------------------------------

class HereDocTester extends UnitTesterNoNorm

	transformValue: (block) ->
		return mapHereDoc(block)

tester = new HereDocTester()

# ---------------------------------------------------------------------------
# Default heredoc type is a block

tester.equal 59, """
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

tester.equal 68, """
		===
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# TAML block

tester.equal 78, """
		---
		- abc
		- def
		""",
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML-like block, but actually a block

tester.equal 88, """
		===
		---
		- abc
		- def
		""",
		'"---\\n- abc\\n- def"'

# ---------------------------------------------------------------------------
# TAML block 2

tester.equal 99, """
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

tester.equal 113, """
		...this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# One Line block

tester.equal 122, """
		...
		this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Function block, with no name or parameters

tester.equal 132, """
		() ->
			return true
		""", """
		() ->
			return true
		"""

# ---------------------------------------------------------------------------
# Function block, with no name but with parameters

tester.equal 143, """
		(x, y) ->
			return true
		""", """
		(x, y) ->
			return true
		"""

# ---------------------------------------------------------------------------
# Test creating a new heredoc type

class MatrixHereDoc extends BaseHereDoc

	isMyHereDoc: (block) ->
		# --- if block starts with a digit
		return block.match(/^\s*\d/)

	map: (block) ->
		lArray = []
		for line in blockToArray(block)
			lArray.push extractMatches(line, /\d+/g, parseInt)
		return JSON.stringify(lArray)

addHereDocType new MatrixHereDoc(), 'matrix'

tester.equal 168, """
		1 2 3
		2 4 6
		""",
		'[[1,2,3],[2,4,6]]'

# ---------------------------------------------------------------------------
# Test creating a new heredoc type by overriding mapToString

class UCHereDoc extends BaseHereDoc

	isMyHereDoc: (block) ->
		return block.indexOf('^^^') == 0

	mapToString: (block) ->
		return block.substring(4).toUpperCase()

addHereDocType new UCHereDoc(), 'upper case'

tester.equal 187, """
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
				mapHereDoc(undented(remainingLines(block)))
			else
				part    # keep as is

		result = lNewParts.join('')
		return result


replacer = new HereDocReplacer()


# ---------------------------------------------------------------------------

replacer.equal 218, """
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

replacer.equal 233, """
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
