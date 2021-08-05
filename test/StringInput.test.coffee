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
	tester.equal 34, item, 'abc'
	item = input.peek()
	tester.equal 36, item, 'abc'
	item = input.get()
	tester.equal 38, item, 'abc'
	item = input.get()
	tester.equal 40, item, 'def'
	input.unget(item)
	item = input.get()
	tester.equal 43, item, 'def'
	input.skip()
	item = input.get()
	tester.equal 46, item, undef

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

tester.equal 69, new StringInput("""
		abc
		def
		"""), [
		'abc',
		'def',
		]

tester.equal 77, new StringInput("""
		abc

		def
		"""), [
		'abc',
		'',
		'def',
		]

tester.equal 87, new StringInput("""
		abc

		def
		""", {
			mapper: (line) ->
				if line == ''
					return undef
				else
					return line
			}), [
		'abc',
		'def',
		]

# ---------------------------------------------------------------------------
# --- Test basic use of mapping function

(()->
	mapper = (line) ->
		if line == ''
			return undef
		else
			return 'x'

	tester.equal 112, new StringInput("""
			abc

			def
			""", {mapper}), [
			'x',
			'x',
			]
	)()

# ---------------------------------------------------------------------------
# --- Test ability to access 'this' object from a mapper
#     Goal: remove not only blank lines, but also the line following

(()->

	mapper = (line, oInput) ->
		if line == ''
			oInput.get()
			return undef
		else
			return line

	tester.equal 135, new StringInput("""
			abc

			def
			ghi
			""", {mapper}), [
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

	mapper = (line, oInput) ->
		lMatches = line.match(cmdRE)
		if lMatches?
			return { cmd: lMatches[1], argstr: lMatches[2] }
		else
			return line

	tester.equal 166, new StringInput("""
			abc
			#if x==y
				def
			#else
				ghi
			""", {mapper}), [
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

	mapper = (line, oInput) ->
		if line == '' || line.match(/^\s*#\s/)
			return undef     # skip comments and blank lines

		n = indentLevel(line)    # current line indent
		while (oInput.lBuffer.length > 0) && (indentLevel(oInput.lBuffer[0]) >= n+2)
			next = oInput.lBuffer.shift()
			line += ' ' + undentedStr(next)
		return line

	tester.equal 196, new StringInput("""
			str = compare(
					"abcde",
					expected
					)

			call func
					with multiple
					long parameters

			# --- DONE ---
			""", {mapper}), [
			'str = compare( "abcde", expected )',
			'call func with multiple long parameters',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test continuation lines AND HEREDOCs

(()->

	mapper = (line, oInput) ->
		if line == '' || line.match(/^\s*#\s/)
			return undef     # skip comments and blank lines

		n = indentLevel(line)    # current line indent
		while (oInput.lBuffer.length > 0) && (indentLevel(oInput.lBuffer[0]) >= n+2)
			next = oInput.lBuffer.shift()
			line += ' ' + undentedStr(next)
		return line

	tester.equal 229, new StringInput("""
			str = compare(
					"abcde",
					expected
					)

			call func
					with multiple
					long parameters

			# --- DONE ---
			""", {mapper}), [
			'str = compare( "abcde", expected )',
			'call func with multiple long parameters',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test overriding the class

(()->

	NewMapper = (line, oInput) ->

		assert oInput instanceof StringInput
		if isEmpty(line)
			return undef
		if line == 'abc'
			return '123'
		else if line == 'def'
			return '456'
		else
			return line

	class NewInput extends StringInput

		constructor: (content, hOptions={}) ->

			assert not hOptions.mapper?
			hOptions.mapper = NewMapper
			super content, hOptions

	tester.equal 272, new NewInput("""
			abc

			def
			"""), [
			'123',
			'456',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test #include

tester.equal 286, new StringInput("""
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
	coffeeMapper = (orgLine) ->
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

	tester.equal 323, new StringInput("""
			\tabc
			\t	myvar <== 2 * 3

			\tdef
			""", {mapper: coffeeMapper}), [
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

	simple.equal 344, oInput.getFileContents('title.md'), "Contents of title.md"
	simple.fails 345, () -> getFileContents('title.txt')

	setUnitTesting(false)
	simple.equal 348, oInput.getFileContents('title.md'), "title\n=====\n"
	setUnitTesting(true)
	)()
