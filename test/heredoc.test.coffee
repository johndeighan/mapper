# heredoc.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, isString, extractMatches, CWS, OL,
	defined, notdefined,
	} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging, debug} from '@jdeighan/coffee-utils/debug'
import {undented} from '@jdeighan/coffee-utils/indent'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'

import {
	lineToParts, mapHereDoc, addHereDocType, isHereDocType,
	BaseHereDoc, addStdHereDocTypes,
	} from '@jdeighan/mapper/heredoc'

addStdHereDocTypes()

# ---------------------------------------------------------------------------

simple.truthy 23, isHereDocType('one line')
simple.truthy 24, isHereDocType('taml')
simple.falsy 25, isHereDocType('two line')

# ---------------------------------------------------------------------------

simple.equal 29, lineToParts('this is not a heredoc'), [
	'this is not a heredoc'
	]

simple.equal 33, lineToParts('this <<< is <<< heredoc'), [
	'this '
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

simple.equal 41, lineToParts('<<< is <<< heredoc'), [
	''
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

simple.equal 49, lineToParts('this <<< is <<<'), [
	'this '
	'<<<'
	' is '
	'<<<'
	''
	]

simple.equal 57, lineToParts('<<< is <<<'), [
	''
	'<<<'
	' is '
	'<<<'
	''
	]

simple.equal 65, lineToParts('<<<'), [
	''
	'<<<'
	''
	]

simple.equal 71, lineToParts('<<<<<<'), [
	''
	'<<<'
	''
	'<<<'
	''
	]

# ---------------------------------------------------------------------------

simple.equal 81, mapHereDoc("""
		abc
		def
		"""), '"abc\\ndef"'

# ---------------------------------------------------------------------------

simple.equal 88, mapHereDoc("""
		===
		abc
		def
		"""), '"abc\\ndef"'

# ---------------------------------------------------------------------------

simple.equal 96, mapHereDoc("""
		...
		abc
		def
		"""), '"abc def"'

# ---------------------------------------------------------------------------

class HereDocTester extends UnitTester

	transformValue: (block) ->

		return mapHereDoc(block)

tester = new HereDocTester()

# ------------------------------------------------------------------------
# Default heredoc type is a block

tester.equal 115, """
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

tester.equal 124, """
		===
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ------------------------------------------------------------------------
# One Line block

tester.equal 134, """
		...this is a
		line of text
		""",
		'"this is a line of text"'

# ------------------------------------------------------------------------
# One Line block

tester.equal 143, """
		...
		this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Test creating new heredoc types

class MatrixHereDoc extends BaseHereDoc

	doMap: (block) ->
		# --- if block starts with a digit
		debug "enter MatrixHereDoc.doMap()", block
		if notdefined(block.match(/^\s*\d/s))
			debug "return undef from MatrixHereDoc.doMap()"
			return undef
		lArray = []
		for line in blockToArray(block)
			lArray.push extractMatches(line, /\d+/g, parseInt)
		result = JSON.stringify(lArray)
		debug "return from MatrixHereDoc.doMap()", result
		return result

addHereDocType 'matrix', MatrixHereDoc

tester.equal 170, """
		1 2 3
		2 4 6
		""",
		'[[1,2,3],[2,4,6]]'

# ------------------------------------------------------------------------
# Test creating a new heredoc type by overriding mapToString

class UCHereDoc extends BaseHereDoc

	doMap: (block) ->

		debug "enter UCHereDoc.doMap()", block
		if (block.indexOf('^^^') != 0)
			debug "return undef from UCHereDoc.doMap()"
			return undef

		block = block.substring(4).toUpperCase()
		debug 'block', block
		result = JSON.stringify(block)
		debug "return from UCHereDoc.doMap()", result
		return result

addHereDocType 'upper case', UCHereDoc

tester.equal 196, """
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

	doMap: (block) ->

		debug "enter UCHereDoc2.doMap()", block
		if (firstLine(block) != '***')
			debug "return undef from UCHereDoc.doMap()"
			return undef

		block = CWS(remainingLines(block).toUpperCase())
		debug 'block', block
		result = JSON.stringify(block)
		debug "return from UCHereDoc2.doMap()", result
		return result

addHereDocType 'upper case 2', UCHereDoc2

# ---------------------------------------------------------------------------

tester.equal 228, """
		***
		select ID,Name
		from Users
		""",
		'"SELECT ID,NAME FROM USERS"'

# ===========================================================================

class HereDocTester extends UnitTester

	transformValue: (block) ->
		return mapHereDoc(block)

tester = new HereDocTester()

# ---------------------------------------------------------------------------
# TAML block

tester.equal 247, """
		---
		- abc
		- def
		""",
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML-like block, but actually a block

tester.equal 257, """
		===
		---
		- abc
		- def
		""",
		'"---\\n- abc\\n- def"'

# ---------------------------------------------------------------------------
# TAML block 2

tester.equal 268, """
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

replacer.equal 297, """
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

replacer.equal 312, """
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

# ---------------------------------------------------------------------------

(() ->

	class HereDocMapper extends UnitTester

		transformValue: (block) ->
			return mapHereDoc(block)

	tester = new HereDocMapper()

	# ------------------------------------------------------------------------

	tester.equal 338, """
			(evt) ->
				log 'click'
			""",
			"""
			(evt) ->
				log 'click'
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name or parameters

	tester.equal 350, """
			() ->
				return true
			""", """
			() ->
				return true
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal 361, """
			(evt) ->
				console.log 'click'
			""", """
			(evt) ->
				console.log 'click'
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal 372, """
			(  evt  )     ->
				log 'click'
			""", """
			(  evt  )     ->
				log 'click'
			"""
	)()
