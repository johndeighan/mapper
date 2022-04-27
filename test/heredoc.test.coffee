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
import {CieloMapper} from '@jdeighan/mapper/cielomapper'

simple = new UnitTesterNorm()

# ---------------------------------------------------------------------------

simple.equal 21, lineToParts('this <<< is <<< heredoc'), [
	'this '
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

simple.equal 29, lineToParts('<<< is <<< heredoc'), [
	'<<<'
	' is '
	'<<<'
	' heredoc'
	]

simple.equal 36, lineToParts('this <<< is <<<'), [
	'this '
	'<<<'
	' is '
	'<<<'
	]

simple.equal 43, lineToParts('<<< is <<<'), [
	'<<<'
	' is '
	'<<<'
	]

simple.equal 49, lineToParts('<<<'), [
	'<<<'
	]

simple.equal 53, lineToParts('<<<<<<'), [
	'<<<'
	'<<<'
	]

# ---------------------------------------------------------------------------

(() ->

	class HereDocTester extends UnitTester

		transformValue: (block) ->
			return mapHereDoc(block).str

	tester = new HereDocTester()

	# ------------------------------------------------------------------------
	# Default heredoc type is a block

	tester.equal 72, """
			this is a
			block of text
			""",
			'"this is a\\nblock of text"'

	# ------------------------------------------------------------------------
	# Make explicit that the heredoc type is a block

	tester.equal 81, """
			===
			this is a
			block of text
			""",
			'"this is a\\nblock of text"'

	# ------------------------------------------------------------------------
	# One Line block

	tester.equal 91, """
			...this is a
			line of text
			""",
			'"this is a line of text"'

	# ------------------------------------------------------------------------
	# One Line block

	tester.equal 100, """
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

	tester.equal 130, """
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

	tester.equal 156, """
			^^^
			This is a
			block of text
			""",
			'"THIS IS A\\nBLOCK OF TEXT"'
	)()

# ---------------------------------------------------------------------------

(() ->

	class SmartTester extends UnitTester

		transformValue: (block) ->
			oInput = new CieloMapper(block, import.meta.url)
			return oInput.getBlock()

	tester = new SmartTester()

	# ---------------------------------------------------------------------------
	# --- test creating a custom HEREDOC section
	#
	#     e.g. with header line ***,
	#     we'll create an upper-cased single line string

	class UCHereDoc2

		myName: () ->
			return 'upper case 2'

		isMyHereDoc: (block) ->
			return firstLine(block) == '***'

		map: (block) ->
			str = CWS(remainingLines(block).toUpperCase())
			return {
				str: JSON.stringify(str)
				obj: str
				}

	addHereDocType new UCHereDoc2()

	# ---------------------------------------------------------------------------

	tester.equal 200, """
			str = <<<
				***
				select ID,Name
				from Users

			""", """
			str = "SELECT ID,NAME FROM USERS"
			"""
	)()
