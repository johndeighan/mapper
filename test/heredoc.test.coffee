# heredoc.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {undef, extractMatches} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {log} from '@jdeighan/coffee-utils/log'
import {
	mapHereDoc, addHereDocType, BaseHereDoc,
	} from '@jdeighan/string-input/heredoc'

simple = new UnitTester()

# ---------------------------------------------------------------------------

class HereDocTester extends UnitTester

	transformValue: (block) ->
		return mapHereDoc(block)

	normalize: (str) ->    # disable normalizing
		return str

tester = new HereDocTester()

# ---------------------------------------------------------------------------
# Default heredoc type is a block

tester.equal  28, """
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

tester.equal  37, """
		$$$
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# TAML block

tester.equal  47, """
		---
		- abc
		- def
		""",
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML-like block, but actually a block

tester.equal  57, """
		$$$
		---
		- abc
		- def
		""",
		'"---\\n- abc\\n- def"'

# ---------------------------------------------------------------------------
# TAML block 2

tester.equal  68, """
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

tester.equal 82, """
		...this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# One Line block

tester.equal 91, """
		...
		this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Function block, with no name or parameters

tester.equal  101, """
		() ->
			return true
		""",
		'() -> return true'

# ---------------------------------------------------------------------------
# Function block, with no name but with parameters

tester.equal  110, """
		(x, y) ->
			return true
		""",
		'(x, y) -> return true'

# ---------------------------------------------------------------------------
# Function block, with name end parameters

tester.equal  119, """
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

addHereDocType(new MatrixHereDoc())

tester.equal  142, """
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

addHereDocType(new UCHereDoc())

tester.equal  161, """
		^^^
		This is a
		block of text
		""",
		'"THIS IS A\\nBLOCK OF TEXT"'
