# StringInput.test.coffee

import {strict as assert} from 'assert'
import {
	say,
	undef,
	pass,
	debug,
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
	tester.equal 41, item, 'abc'
	item = input.peek()
	tester.equal 43, item, 'abc'
	item = input.get()
	tester.equal 45, item, 'abc'
	item = input.get()
	tester.equal 47, item, 'def'
	input.unget(item)
	item = input.get()
	tester.equal 50, item, 'def'
	input.skip()
	item = input.get()
	tester.equal 53, item, undef

	)()

# ---------------------------------------------------------------------------

class GatherTester extends AvaTester

	transformValue: (oInput) ->
		if oInput not instanceof StringInput
			throw new Error("oInput should be a StringInput object")
		return oInput.getAll()

tester = new GatherTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 71, new StringInput("""
		abc
		def
		"""), [
		'abc',
		'def',
		]

tester.equal 79, new StringInput("""
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

	tester.equal 98, new TestInput("""
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

	tester.equal 120, new TestInput("""
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

	tester.equal 145, new TestInput("""
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

	tester.equal 178, new TestInput("""
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

	tester.equal 210, new TestInput("""
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

	tester.equal 245, new TestInput("""
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

		mapLine: (line) ->

			if isEmpty(line)
				return undef
			if line == 'abc'
				return '123'
			else if line == 'def'
				return '456'
			else
				return line

	tester.equal 281, new TestInput("""
			abc

			def
			"""), [
			'123',
			'456',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test #include

tester.equal 295, new StringInput("""
		abc
			#include title.md
		def
		""", {
			hIncludePaths: {
				'.md': 'c:\\Users\\johnd\\string-input\\src\\markdown',
				}
			}), [
		'abc',
		'\tContents of title.md',
		'def',
		]

# ---------------------------------------------------------------------------
# --- Test #include with unit testing off

setUnitTesting(false)
tester.equal 313, new StringInput("""
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
setUnitTesting(true)

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

	tester.equal 353, new TestInput("""
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
# --- Test #include inside block processed by fetchBlock()

(() ->
	text = """
			p a paragraph
			div:markdown
				#include title.md
			"""

	block = undef
	class TestParser extends StringInput

		mapLine: (line) ->
			if line == 'div:markdown'
				block = @fetchBlock(1)
			return line

	oInput = new TestParser(text, {
			hIncludePaths: {'.md': 'somewhere'}
			})
	line = oInput.get()
	simple.equal 387, line, 'p a paragraph'
	line = oInput.get()
	simple.equal 389, line, 'div:markdown'
	simple.equal 390, block, 'Contents of title.md'
	)()

# ---------------------------------------------------------------------------

(() ->
	text = """
			p a paragraph
			div:markdown
				#include title.md
			"""
	block = undef
	class TestParser extends StringInput

		mapLine: (line) ->
			if line == 'div:markdown'
				block = @fetchBlock(1)
			return line

	setUnitTesting(false)
	oInput = new TestParser(text, {
			hIncludePaths: {
				'.md': 'c:\\Users\\johnd\\string-input\\src\\markdown',
				}
			})
	line = oInput.get()
	simple.equal 416, line, 'p a paragraph'

	line = oInput.get()
	simple.equal 419, line, 'div:markdown'

	simple.equal 421, block, '\ttitle\n\t====='

	setUnitTesting(true)
	)()

# ---------------------------------------------------------------------------

(() ->
	text = """
			p a paragraph
			div:markdown
				#include header.md
			"""

	### Contents of files used:

	```header.md
	header
	======

		#include para.md
	```

	```para.md
	para
	----
	```
	###

	oInput = new StringInput(text, {
			hIncludePaths: {
				'.md': 'c:\\Users\\johnd\\string-input\\src\\markdown',
				}
			})

	setUnitTesting(false)
	tester.equal 441, oInput, [
		"p a paragraph"
		"div:markdown"
		"\theader"
		"\t======"
		"\t"
		"\t\tpara"
		"\t\t----"
		]
	setUnitTesting(true)
	)()
