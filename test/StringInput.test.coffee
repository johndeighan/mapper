# StringInput.test.coffee

import {strict as assert} from 'assert'
import {
	say,
	undef,
	isEmpty,
	setDebugging,
	debugging,
	setUnitTesting,
	unitTesting,
	escapeStr,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel,
	undentedStr,
	splitLine,
	indentedStr,
	indentedBlock,
	} from '@jdeighan/coffee-utils/indent'
import {StringInput} from '../src/StringInput.js'
import {AvaTester} from '@jdeighan/ava-tester'

simple = new AvaTester()
setUnitTesting(true)

# ---------------------------------------------------------------------------

(() ->
	tester = new AvaTester()

	input = new StringInput("""
			abc
			def
			ghi
			""")

	item = input.peek()
	tester.equal 39, item, 'abc'
	item = input.peek()
	tester.equal 41, item, 'abc'
	item = input.get()
	tester.equal 43, item, 'abc'
	item = input.get()
	tester.equal 45, item, 'def'
	input.unget(item)
	item = input.get()
	tester.equal 48, item, 'def'
	input.skip()
	item = input.get()
	tester.equal 51, item, undef

	)()

# ---------------------------------------------------------------------------

class GatherTester extends AvaTester

	transformValue: (input) ->
		if input not instanceof StringInput
			throw new Error("input should be a StringInput object")
		lLines = []
		line = input.get()
		while line?
			lLines.push(line)
			line = input.get()
		return lLines

tester = new GatherTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 74, new StringInput("""
		abc
		def
		"""), [
		'abc',
		'def',
		]

tester.equal 82, new StringInput("""
		abc

		def
		"""), [
		'abc',
		'',
		'def',
		]

(() ->
	class TestInput extends StringInput

		mapLine: (line) ->
			if line == ''
				return undef
			else
				return line

	tester.equal 101, new TestInput("""
			abc

			def
			"""), [
			'abc',
			'def',
			]
	)()

# ---------------------------------------------------------------------------
# --- Test basic use of mapping function

(()->
	class TestInput extends StringInput

		mapLine: (line) ->
			if line == ''
				return undef
			else
				return 'x'

	tester.equal 123, new TestInput("""
			abc

			def
			"""), [
			'x',
			'x',
			]
	)()

# ---------------------------------------------------------------------------
# --- Test ability to access 'this' object from a mapper
#     Goal: remove not only blank lines, but also the line following

(()->

	class TestInput extends StringInput

		mapLine: (line) ->
			if line == ''
				follow = @fetch()
				return undef
			else
				return line

	tester.equal 148, new TestInput("""
			abc

			def
			ghi
			"""), [
			'abc',
			'ghi',
			]
	)()

# ---------------------------------------------------------------------------

# --- Test mapping to objects

(()->

	cmdRE = ///^
			\s*                # skip leading whitespace
			\# ([a-z][a-z_]*)  # command name
			\s*                # skipwhitespace following command
			(.*)               # command arguments
			$///

	class TestInput extends StringInput

		mapLine: (line) ->
			lMatches = line.match(cmdRE)
			if lMatches?
				return { cmd: lMatches[1], argstr: lMatches[2] }
			else
				return line

	tester.equal 181, new TestInput("""
			abc
			#if x==y
				def
			#else
				ghi
			"""), [
			'abc',
			{ cmd: 'if', argstr: 'x==y' },
			'\tdef',
			{ cmd: 'else', argstr: '' },
			'\tghi'
			]
	)()

# ---------------------------------------------------------------------------
# --- Test continuation lines

(()->

	class TestInput extends StringInput

		mapLine: (line) ->
			if line == '' || line.match(/^\s*#\s/)
				return undef     # skip comments and blank lines

			n = indentLevel(line)    # current line indent
			while (@lBuffer.length > 0) && (indentLevel(@lBuffer[0]) >= n+2)
				next = @lBuffer.shift()
				line += ' ' + undentedStr(next)
			return line

	tester.equal 213, new TestInput("""
			str = compare(
					"abcde",
					expected
					)

			call func
					with multiple
					long parameters

			# --- DONE ---
			"""), [
			'str = compare( "abcde", expected )',
			'call func with multiple long parameters',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test continuation lines AND HEREDOCs

(()->

	class TestInput extends StringInput

		mapLine: (line) ->
			if line == '' || line.match(/^\s*#\s/)
				return undef     # skip comments and blank lines

			n = indentLevel(line)    # current line indent
			while (@lBuffer.length > 0) && (indentLevel(@lBuffer[0]) >= n+2)
				next = @lBuffer.shift()
				line += ' ' + undentedStr(next)
			return line

	tester.equal 248, new TestInput("""
			str = compare(
					"abcde",
					expected
					)

			call func
					with multiple
					long parameters

			# --- DONE ---
			"""), [
			'str = compare( "abcde", expected )',
			'call func with multiple long parameters',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test overriding the class

(()->


	class TestInput extends StringInput

		constructor: (content) ->

			super content

		mapLine: (line) ->

			if isEmpty(line)
				return undef
			if line == 'abc'
				return '123'
			else if line == 'def'
				return '456'
			else
				return line

	tester.equal 289, new TestInput("""
			abc

			def
			"""), [
			'123',
			'456',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test #include

tester.equal 303, new StringInput("""
		abc
			#include title.md
		def
		""", {
			hIncludePaths: {
				'.md': 'c:\\Users\\johnd\\string-input\\src\\markdown',
				}
			}), [
		'abc',
		'\ttitle',
		'\t=====',
		'def',
		]

# ---------------------------------------------------------------------------
# --- Test advanced use of mapping function

(()->
	class TestInput extends StringInput

		mapLine: (orgLine) ->
			[level, line] = splitLine(orgLine)
			if isEmpty(line) || line.match(/^#\s/)
				return undef
			if lMatches = line.match(///^
					(?:
						([A-Za-z][A-Za-z0-9_]*)   # variable name
						\s*
						)?
					\<\=\=
					\s*
					(.*)
					$///)
				result = indentedStr(line, level)
			else
				result = orgLine
			return result

	tester.equal 342, new TestInput("""
			\tabc
			\t	myvar <== 2 * 3

			\tdef
			"""), [
			'\tabc'
			'\t\tmyvar <== 2 * 3'
			'\tdef'
			]
	)()

# ---------------------------------------------------------------------------
# test getFileContents

(()->
	oInput = new StringInput('nothing', {
		hIncludePaths:
			'.md': 'c:/Users/johnd/string-input/src/markdown'
		})

	simple.equal 363, oInput.getFileContents('title.md'), "Contents of title.md"
	simple.fails 364, () -> getFileContents('title.txt')

	setUnitTesting(false)
	simple.equal 367, oInput.getFileContents('title.md'), "title\n=====\n"
	setUnitTesting(true)
	)()
