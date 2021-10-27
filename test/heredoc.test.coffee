# heredoc.test.coffee

import {undef} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {log} from '@jdeighan/coffee-utils/log'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {
	mapHereDoc, addHereDocType, BaseHereDoc,
	} from '@jdeighan/string-input/heredoc'

simple = new UnitTester()

# ---------------------------------------------------------------------------
# Default heredoc type is a block

simple.equal  13, mapHereDoc("""
		this is a
		block of text
		"""),
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

simple.equal  22, mapHereDoc("""
		$$$
		this is a
		block of text
		"""),
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# TAML block

simple.equal  32, mapHereDoc("""
		---
		- abc
		- def
		"""),
		'["abc","def"]'

# ---------------------------------------------------------------------------
# One Line block

simple.equal  42, mapHereDoc("""
		...this is a
		line of text
		"""),
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Function block, with no name or parameters

simple.equal  51, mapHereDoc("""
		() ->
			return true
		"""),
		'() -> return true'

# ---------------------------------------------------------------------------
# Function block, with no name but with parameters

simple.equal  60, mapHereDoc("""
		(x, y) ->
			return true
		"""),
		'(x, y) -> return true'

# ---------------------------------------------------------------------------
# Function block, with name end parameters

simple.equal  69, mapHereDoc("""
		func = (x, y) ->
			return true
		"""),
		'func = (x, y) -> return true'

# ---------------------------------------------------------------------------
# function extractNumbers()

extractNumbers = (line) ->

	lStrings = [...line.matchAll(/\d+(?:\.\d*)?/g)]
	lNumbers = for str in lStrings
		parseInt(str)
	return lNumbers

simple.equal 87, extractNumbers("0 1 2"),     [0, 1, 2]
simple.equal 88, extractNumbers("0, 1, 2"),   [0, 1, 2]
simple.equal 89, extractNumbers("[0, 1, 2]"), [0, 1, 2]

# ---------------------------------------------------------------------------
# Test creating a new heredoc type

class MatrixHereDoc extends BaseHereDoc

	isMyHereDoc: (block) ->
		# --- if block starts with a digit
		return block.match(/^\s*\d/)

	map: (block) ->
		lArray = []
		for line in blockToArray(block)
			lArray.push extractNumbers(line)
		return JSON.stringify(lArray)

addHereDocType(new MatrixHereDoc())

simple.equal  106, mapHereDoc("""
		1 2 3
		2 4 6
		"""),
		'[[1,2,3],[2,4,6]]'
