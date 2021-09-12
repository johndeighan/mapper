# StringInput.test.coffee

import {strict as assert} from 'assert'

import {
	undef, pass, isEmpty,
	setUnitTesting, unitTesting,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {
	debug, debugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {StringInput} from '@jdeighan/string-input'

dir = mydir(`import.meta.url`)
process.env.DIR_MARKDOWN = mkpath(dir, 'markdown')

simple = new UnitTester()
setUnitTesting true

###
	class StringInput should handle the following:
		- #include <file> statements, when DIR_* env vars are set
		- get(), peek(), unget(), skip()
		- overriding of mapLine() to return alternate strings or objects
		- fetch() and fetchBlock() inside mapLine()
###

# ---------------------------------------------------------------------------
# --- test get(), peek(), unget(), skip()

(() ->
	input = new StringInput("""
			abc
			def
			ghi
			""")

	item = input.peek()
	simple.equal 44, item, 'abc'
	item = input.peek()
	simple.equal 46, item, 'abc'
	item = input.get()
	simple.equal 48, item, 'abc'
	item = input.get()
	simple.equal 50, item, 'def'
	input.unget(item)
	item = input.get()
	simple.equal 53, item, 'def'
	input.skip()
	item = input.get()
	simple.equal 56, item, undef
	)()

# ---------------------------------------------------------------------------

class GatherTester extends UnitTester

	transformValue: (oInput) ->

		assert oInput instanceof StringInput,
			"oInput should be a StringInput object"
		return oInput.getAll()

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
# --- Test implementing continuation lines

(()->

	class TestInput extends StringInput

		mapLine: (line) ->
			if line == '' || line.match(/^\s*#\s/)
				return undef     # skip comments and blank lines

			n = indentLevel(line)    # current line indent
			while (@lBuffer.length > 0) && (indentLevel(@lBuffer[0]) >= n+2)
				next = @lBuffer.shift()
				line += ' ' + undented(next)
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
# --- Test continuation lines

(()->

	class TestInput extends StringInput

		mapLine: (line) ->
			if line == '' || line.match(/^\s*#\s/)
				return undef     # skip comments and blank lines

			n = indentLevel(line)    # current line indent
			while (@lBuffer.length > 0) && (indentLevel(@lBuffer[0]) >= n+2)
				next = @lBuffer.shift()
				line += ' ' + undented(next)
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

		mapLine: (line) ->

			if isEmpty(line)
				return undef
			if line == 'abc'
				return '123'
			else if line == 'def'
				return '456'
			else
				return line

	tester.equal 284, new TestInput("""
			abc

			def
			"""), [
			'123',
			'456',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test #include

tester.equal 298, new StringInput("""
		abc
			#include title.md
		def
		"""), [
		'abc',
		'\tContents of title.md',
		'def',
		]

# ---------------------------------------------------------------------------
# --- Test #include with unit testing off

setUnitTesting false
tester.equal 312, new StringInput("""
		abc
			#include title.md
		def
		"""), [
		'abc',
		'\ttitle',
		'\t=====',
		'def',
		]
setUnitTesting true

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
				result = indented(line, level)
			else
				result = orgLine
			return result

	tester.equal 348, new TestInput("""
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

	oInput = new TestParser(text)
	line = oInput.get()
	simple.equal 380, line, 'p a paragraph'
	line = oInput.get()
	simple.equal 382, line, 'div:markdown'
	simple.equal 383, block, 'Contents of title.md'
	)()

# ---------------------------------------------------------------------------
# --- Test blank lines inside a block

(() ->
	text = """
			p a paragraph
			div:markdown
				line 1

				line 3
			"""

	block = undef
	class TestParser extends StringInput

		mapLine: (line) ->
			if line == 'div:markdown'
				block = @fetchBlock(1)
			return line

	oInput = new TestParser(text)
	line = oInput.get()
	simple.equal 408, line, 'p a paragraph'
	line = oInput.get()
	simple.equal 410, line, 'div:markdown'
	simple.equal 411, block, """
			line 1

			line 3
			"""
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

	setUnitTesting false
	oInput = new TestParser(text)
	line = oInput.get()
	simple.equal 437, line, 'p a paragraph'

	line = oInput.get()
	simple.equal 440, line, 'div:markdown'

	simple.equal 442, block, '\ttitle\n\t====='

	setUnitTesting true
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

	oInput = new StringInput(text)

	setUnitTesting false
	tester.equal 473, oInput, [
		"p a paragraph"
		"div:markdown"
		"\theader"
		"\t======"
		""
		"\t\tpara"
		"\t\t----"
		]
	setUnitTesting true
	)()

# ---------------------------------------------------------------------------
# --- Test comment

tester.equal 488, new StringInput("""
		abc

		# --- this is a comment

		def
		"""), [
		'abc',
		'',
		'# --- this is a comment',
		'',
		'def',
		]
