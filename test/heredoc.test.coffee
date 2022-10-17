# heredoc.test.coffee

import {LOG, debug, assert, croak} from '@jdeighan/exceptions'
import {setDebugging} from '@jdeighan/exceptions/debug'
import {UnitTester, tester} from '@jdeighan/unit-tester'
import {
	undef, isString, extractMatches, CWS, OL,
	defined, notdefined,
	} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {undented} from '@jdeighan/coffee-utils/indent'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'

import {
	lineToParts, mapHereDoc, addHereDocType, isHereDocType, BaseHereDoc,
	} from '@jdeighan/mapper/heredoc'

# ---------------------------------------------------------------------------

tester.truthy 20, isHereDocType('one line')
tester.truthy 21, isHereDocType('taml')
tester.falsy 22, isHereDocType('two line')

# ---------------------------------------------------------------------------

tester.equal 26, lineToParts('this is not a heredoc'), [
	'this is not a heredoc'
	]

tester.equal 30, lineToParts('this <<< is <<< heredoc'), [
	'this '
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

tester.equal 38, lineToParts('<<< is <<< heredoc'), [
	''
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

tester.equal 46, lineToParts('this <<< is <<<'), [
	'this '
	'<<<'
	' is '
	'<<<'
	''
	]

tester.equal 54, lineToParts('<<< is <<<'), [
	''
	'<<<'
	' is '
	'<<<'
	''
	]

tester.equal 62, lineToParts('<<<'), [
	''
	'<<<'
	''
	]

tester.equal 68, lineToParts('<<<<<<'), [
	''
	'<<<'
	''
	'<<<'
	''
	]

# ---------------------------------------------------------------------------

tester.equal 78, mapHereDoc("""
		abc
		def
		"""),
		'"abc\\ndef"'

# ---------------------------------------------------------------------------

tester.equal 86, mapHereDoc("""
		===
		abc
		def
		"""),
		'"abc\\ndef"'

# ---------------------------------------------------------------------------

tester.equal 95, mapHereDoc("""
		...
		abc
		def
		"""),
		'"abc def"'

# ---------------------------------------------------------------------------

tester.equal 104, mapHereDoc("""
		() -> count += 1
		"""),
		'() -> count += 1'

# ---------------------------------------------------------------------------

tester.equal 111, mapHereDoc("""
		---
		a: 1
		b: 2
		"""),
		'{"a":1,"b":2}'

# ---------------------------------------------------------------------------

tester.equal 120, mapHereDoc("""
		---
		- a
		- b
		"""),
		'["a","b"]'

# ---------------------------------------------------------------------------

class HereDocTester extends UnitTester

	transformValue: (block) ->

		return mapHereDoc(block)

docTester = new HereDocTester()

# ------------------------------------------------------------------------
# Default heredoc type is a block

docTester.equal 140, """
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ------------------------------------------------------------------------
# Make explicit that the heredoc type is a block

docTester.equal 149, """
		===
		this is a
		block of text
		""",
		'"this is a\\nblock of text"'

# ------------------------------------------------------------------------
# One Line block

docTester.equal 159, """
		...this is a
		line of text
		""",
		'"this is a line of text"'

# ------------------------------------------------------------------------
# One Line block

docTester.equal 168, """
		...
		this is a
		line of text
		""",
		'"this is a line of text"'

# ---------------------------------------------------------------------------
# Test creating new heredoc types

class MatrixHereDoc extends BaseHereDoc

	map: (block) ->
		# --- if block starts with a digit
		debug "enter MatrixHereDoc.map()", block
		if notdefined(block.match(/^\s*\d/s))
			debug "return undef from MatrixHereDoc.map()"
			return undef
		lArray = []
		for line in blockToArray(block)
			lArray.push extractMatches(line, /\d+/g, parseInt)
		result = JSON.stringify(lArray)
		debug "return from MatrixHereDoc.map()", result
		return result

addHereDocType 'matrix', MatrixHereDoc

docTester.equal 195, """
		1 2 3
		2 4 6
		""",
		'[[1,2,3],[2,4,6]]'

# ------------------------------------------------------------------------
# Test creating a new heredoc type by overriding mapToString

class UCHereDoc extends BaseHereDoc

	map: (block) ->

		debug "enter UCHereDoc.map()", block
		if (block.indexOf('^^^') != 0)
			debug "return undef from UCHereDoc.map()"
			return undef

		block = block.substring(4).toUpperCase()
		debug 'block', block
		result = JSON.stringify(block)
		debug "return from UCHereDoc.map()", result
		return result

addHereDocType 'upper case', UCHereDoc

docTester.equal 221, """
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

	map: (block) ->

		debug "enter UCHereDoc2.map()", block
		if (firstLine(block) != '***')
			debug "return undef from UCHereDoc.map()"
			return undef

		block = CWS(remainingLines(block).toUpperCase())
		debug 'block', block
		result = JSON.stringify(block)
		debug "return from UCHereDoc2.map()", result
		return result

addHereDocType 'upper case 2', UCHereDoc2

# ---------------------------------------------------------------------------

docTester.equal 253, """
		***
		select ID,Name
		from Users
		""",
		'"SELECT ID,NAME FROM USERS"'

# ===========================================================================

class HereDocTester extends UnitTester

	transformValue: (block) ->
		return mapHereDoc(block)

docTester = new HereDocTester()

# ---------------------------------------------------------------------------
# TAML block

docTester.equal 272, """
		---
		- abc
		- def
		""",
		'["abc","def"]'

# ---------------------------------------------------------------------------
# TAML-like block, but actually a block

docTester.equal 282, """
		===
		---
		- abc
		- def
		""",
		'"---\\n- abc\\n- def"'

# ---------------------------------------------------------------------------
# TAML block 2

docTester.equal 293, """
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

replacer.equal 322, """
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

replacer.equal 337, """
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

	docTester = new HereDocMapper()

	# ------------------------------------------------------------------------

	docTester.equal 363, """
			(evt) ->
				LOG 'click'
			""",
			"""
			(evt) ->
				LOG 'click'
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name or parameters

	docTester.equal 375, """
			() ->
				return true
			""", """
			() ->
				return true
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	docTester.equal 386, """
			(evt) ->
				console.log 'click'
			""", """
			(evt) ->
				console.log 'click'
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	docTester.equal 397, """
			(  evt  )     ->
				LOG 'click'
			""", """
			(  evt  )     ->
				LOG 'click'
			"""
	)()
