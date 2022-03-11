# heredoc.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {assert, undef, extractMatches} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {log} from '@jdeighan/coffee-utils/log'
import {
	mapHereDoc, addHereDocType, BaseHereDoc, lineToParts, doDebug,
	} from '@jdeighan/string-input/heredoc'

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
simple.equal 29, lineToParts('this <<< is <<<'), [
	'this '
	'<<<'
	' is '
	'<<<'
	]
simple.equal 36, lineToParts('<<< is <<<'), [
	'<<<'
	' is '
	'<<<'
	]
simple.equal 43, lineToParts('<<<'), [
	'<<<'
	]
simple.equal 43, lineToParts('<<<<<<'), [
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

tester.equal  61, """
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

tester.equal  70, """
		===
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# TAML block

tester.equal  80, """
		---
		- abc
		- def
		""",
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML-like block, but actually a block

tester.equal  90, """
		===
		---
		- abc
		- def
		""",
		'"---\\n- abc\\n- def"'

# ---------------------------------------------------------------------------
# TAML block 2

tester.equal  101, """
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

tester.equal 115, """
		...this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# One Line block

tester.equal 124, """
		...
		this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Function block, with no name or parameters

tester.equal  134, """
		() ->
			return true
		""",
		'() -> return true'

# ---------------------------------------------------------------------------
# Function block, with no name but with parameters

tester.equal  143, """
		(x, y) ->
			return true
		""",
		'(x, y) -> return true'

# ---------------------------------------------------------------------------
# Function block, with name end parameters

tester.equal  152, """
		func = (x, y) ->
			return true
		""",
		'func = (x, y) -> return true'

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

tester.equal  175, """
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

tester.equal  194, """
		^^^
		This is a
		block of text
		""",
		'"THIS IS A\\nBLOCK OF TEXT"'
