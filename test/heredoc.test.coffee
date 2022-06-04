# heredoc.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {
	assert, undef, isString, extractMatches, CWS, OL,
	} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {undented} from '@jdeighan/coffee-utils/indent'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'

import {
	lineToParts, mapHereDoc, addHereDocType,
	} from '@jdeighan/mapper/heredoc'

simple = new UnitTesterNorm()

# ---------------------------------------------------------------------------

simple.equal 20, lineToParts('this is not a heredoc'), [
	'this is not a heredoc'
	]

simple.equal 24, lineToParts('this <<< is <<< heredoc'), [
	'this '
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

simple.equal 32, lineToParts('<<< is <<< heredoc'), [
	''
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

simple.equal 40, lineToParts('this <<< is <<<'), [
	'this '
	'<<<'
	' is '
	'<<<'
	''
	]

simple.equal 48, lineToParts('<<< is <<<'), [
	''
	'<<<'
	' is '
	'<<<'
	''
	]

simple.equal 56, lineToParts('<<<'), [
	''
	'<<<'
	''
	]

simple.equal 62, lineToParts('<<<<<<'), [
	''
	'<<<'
	''
	'<<<'
	''
	]

# ---------------------------------------------------------------------------

simple.equal 72, mapHereDoc("""
		abc
		def
		"""), {
			str: '"abc\\ndef"'
			obj: "abc\ndef"
			type: 'string'
			}

# ---------------------------------------------------------------------------

simple.equal 83, mapHereDoc("""
		===
		abc
		def
		"""), {
			str: '"abc\\ndef"'
			obj: "abc\ndef"
			type: 'string'
			}

# ---------------------------------------------------------------------------

simple.equal 95, mapHereDoc("""
		...
		abc
		def
		"""), {
			str: '"abc def"'
			obj: "abc def"
			type: 'string'
			}

# ---------------------------------------------------------------------------

class HereDocTester extends UnitTester

	transformValue: (block) ->
		return mapHereDoc(block).str

tester = new HereDocTester()

# ------------------------------------------------------------------------
# Default heredoc type is a block

tester.equal 117, """
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

tester.equal 126, """
		===
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ------------------------------------------------------------------------
# One Line block

tester.equal 136, """
		...this is a
		line of text
		""",
		'"this is a line of text"'

# ------------------------------------------------------------------------
# One Line block

tester.equal 145, """
		...
		this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Test creating new heredoc types

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

tester.equal 175, """
		1 2 3
		2 4 6
		""",
		'[[1,2,3],[2,4,6]]'

# ------------------------------------------------------------------------
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

tester.equal 201, """
		^^^
		This is a
		block of text
		""",
		'"THIS IS A\\nBLOCK OF TEXT"'

# ---------------------------------------------------------------------------
# --- test creating a custom HEREDOC section
#
#     e.g. with header line ***,
#     we'll create an upper-cased single line string

class UCHereDoc2

	myName: () ->
		return 'upper case 2'

	isMyHereDoc: (block) ->
		return (firstLine(block) == '***')

	map: (block) ->
		block = remainingLines(block).toUpperCase()
		str = CWS(block)
		return {
			str: JSON.stringify(str)
			obj: str
			type: 'string'
			}

addHereDocType new UCHereDoc2()

# ---------------------------------------------------------------------------

tester.equal 235, """
		***
		select ID,Name
		from Users
		""",
		'"SELECT ID,NAME FROM USERS"'
