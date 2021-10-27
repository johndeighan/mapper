# heredoc.test.coffee

import {undef, extractMatches} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {log} from '@jdeighan/coffee-utils/log'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {
	mapHereDoc, addHereDocType, BaseHereDoc,
	} from '@jdeighan/string-input/heredoc'

simple = new UnitTester()

# ---------------------------------------------------------------------------
# Default heredoc type is a block

simple.equal  16, mapHereDoc("""
		this is a
		block of text
		"""),
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

simple.equal  25, mapHereDoc("""
		$$$
		this is a
		block of text
		"""),
		'"this is a\\nblock of text"'

# ---------------------------------------------------------------------------
# TAML block

simple.equal  35, mapHereDoc("""
		---
		- abc
		- def
		"""),
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML block 2

simple.equal  45, mapHereDoc("""
		---
		-
			label: Help
			url: /help
		-
			label: Books
			url: /books
		"""),
		'[{"label":"Help","url":"/help"},{"label":"Books","url":"/books"}]'

# ---------------------------------------------------------------------------
# One Line block

simple.equal  59, mapHereDoc("""
		...this is a
		line of text
		"""),
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Function block, with no name or parameters

simple.equal  68, mapHereDoc("""
		() ->
			return true
		"""),
		'() -> return true'

# ---------------------------------------------------------------------------
# Function block, with no name but with parameters

simple.equal  77, mapHereDoc("""
		(x, y) ->
			return true
		"""),
		'(x, y) -> return true'

# ---------------------------------------------------------------------------
# Function block, with name end parameters

simple.equal  86, mapHereDoc("""
		func = (x, y) ->
			return true
		"""),
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

simple.equal  109, mapHereDoc("""
		1 2 3
		2 4 6
		"""),
		'[[1,2,3],[2,4,6]]'
