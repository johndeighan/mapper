# heredoc.test.coffee

import {
	undef, isString, OL, defined, notdefined, toArray,
	CWS, extractMatches,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn, setDebugging,
	} from '@jdeighan/base-utils/debug'
import {UnitTester, utest} from '@jdeighan/unit-tester'
import {undented} from '@jdeighan/coffee-utils/indent'
import {
	firstLine, remainingLines,
	} from '@jdeighan/coffee-utils/block'

import {
	lineToParts, mapHereDoc, addHereDocType, BaseHereDoc,
	} from '@jdeighan/mapper/heredoc'

# ---------------------------------------------------------------------------

utest.equal 24, lineToParts('this is not a heredoc'), [
	'this is not a heredoc'
	]

utest.equal 28, lineToParts('this <<< is <<< heredoc'), [
	'this '
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

utest.equal 36, lineToParts('<<< is <<< heredoc'), [
	''
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

utest.equal 44, lineToParts('this <<< is <<<'), [
	'this '
	'<<<'
	' is '
	'<<<'
	''
	]

utest.equal 52, lineToParts('<<< is <<<'), [
	''
	'<<<'
	' is '
	'<<<'
	''
	]

utest.equal 60, lineToParts('<<<'), [
	''
	'<<<'
	''
	]

utest.equal 66, lineToParts('<<<<<<'), [
	''
	'<<<'
	''
	'<<<'
	''
	]

# ---------------------------------------------------------------------------

class HereDocTester extends UnitTester

	transformValue: (block) ->

		return mapHereDoc(block)

tester = new HereDocTester()

# ---------------------------------------------------------------------------

utest.equal 86, mapHereDoc("""
		abc
		def
		"""),
		'"abc\\ndef"'

# ---------------------------------------------------------------------------

utest.equal 94, mapHereDoc("""
		===
		abc
		def
		"""),
		'"abc\\ndef"'

# ---------------------------------------------------------------------------

utest.equal 103, mapHereDoc("""
		...
		abc
		def
		"""),
		'"abc def"'

# ---------------------------------------------------------------------------

utest.equal 112, mapHereDoc("""
		---
		a: 1
		b: 2
		"""),
		'{"a":1,"b":2}'

# ---------------------------------------------------------------------------

utest.equal 121, mapHereDoc("""
		---
		- a
		- b
		"""),
		'["a","b"]'

# ------------------------------------------------------------------------
# Default heredoc type is a block

tester.equal 131, """
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

tester.equal 140, """
		===
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ------------------------------------------------------------------------
# One Line block

tester.equal 150, """
		...this is a
		line of text
		""",
		'"this is a line of text"'

# ------------------------------------------------------------------------
# One Line block

tester.equal 159, """
		...
		this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Test creating new heredoc types

class MatrixHereDoc extends BaseHereDoc

	mapToCielo: (block) ->
		# --- if block starts with a digit
		dbgEnter "MatrixHereDoc.mapToCielo", block
		if notdefined(block.match(/^\s*\d/s))
			dbgReturn "MatrixHereDoc.mapToCielo", undef
			return undef
		lArray = []
		for line in toArray(block)
			lArray.push extractMatches(line, /\d+/g, parseInt)
		result = JSON.stringify(lArray)
		dbgReturn "MatrixHereDoc.mapToCielo", result
		return result

addHereDocType 'matrix', new MatrixHereDoc()

tester.equal 186, """
		1 2 3
		2 4 6
		""",
		'[[1,2,3],[2,4,6]]'

# ------------------------------------------------------------------------
# Test creating a new heredoc type by overriding mapToString

class UCHereDoc extends BaseHereDoc

	mapToCielo: (block) ->

		dbgEnter "UCHereDoc.mapToCielo", block
		if (block.indexOf('^^^') != 0)
			dbgReturn "UCHereDoc.mapToCielo", undef
			return undef

		block = block.substring(4).toUpperCase()
		dbg 'block', block
		result = JSON.stringify(block)
		dbgReturn "UCHereDoc.mapToCielo", result
		return result

addHereDocType 'upper case', new UCHereDoc()

tester.equal 212, """
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

class UCHereDoc2 extends BaseHereDoc

	mapToCielo: (block) ->

		dbgEnter "UCHereDoc2.mapToCielo", block
		if (firstLine(block) != '***')
			dbgReturn "UCHereDoc2.mapToCielo", undef
			return undef

		block = CWS(remainingLines(block).toUpperCase())
		dbg 'block', block
		result = JSON.stringify(block)
		dbgReturn "UCHereDoc2.mapToCielo", result
		return result

addHereDocType 'upper case 2', new UCHereDoc2()

# ---------------------------------------------------------------------------

tester.equal 244, """
		***
		select ID,Name
		from Users
		""",
		'"SELECT ID,NAME FROM USERS"'

# ---------------------------------------------------------------------------
# TAML block

tester.equal 254, """
		---
		- abc
		- def
		""",
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML-like block, but actually a block

tester.equal 264, """
		===
		---
		- abc
		- def
		""",
		'"---\\n- abc\\n- def"'

# ---------------------------------------------------------------------------
# TAML block 2

tester.equal 275, """
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

class HereDocReplacer extends UnitTester

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

replacer.equal 304, """
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

replacer.equal 319, """
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
