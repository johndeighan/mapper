# StringInput.test.coffee

import {strict as assert} from 'assert'
import {resolve} from 'path'

import {AvaTester} from '@jdeighan/ava-tester'
import {
	say, undef, pass, isEmpty,
	setUnitTesting, unitTesting, escapeStr,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undentedStr, splitLine,
	indentedStr, indentedBlock,
	} from '@jdeighan/coffee-utils/indent'
import {
	debug, debugging, setDebugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {StringInput} from '@jdeighan/string-input'

dir = mydir(`import.meta.url`)
root = resolve(dir, '..')
process.env.DIR_MARKDOWN = mkpath(root, 'src', 'markdown')

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
	tester.equal 40, item, 'abc'
	item = input.peek()
	tester.equal 42, item, 'abc'
	item = input.get()
	tester.equal 44, item, 'abc'
	item = input.get()
	tester.equal 46, item, 'def'
	input.unget(item)
	item = input.get()
	tester.equal 49, item, 'def'
	input.skip()
	item = input.get()
	tester.equal 52, item, undef

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

tester.equal 70, new StringInput("""
		abc
		def
		"""), [
		'abc',
		'def',
		]

tester.equal 78, new StringInput("""
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

	tester.equal 97, new TestInput("""
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

	tester.equal 119, new TestInput("""
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

	tester.equal 144, new TestInput("""
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

	tester.equal 177, new TestInput("""
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

	tester.equal 209, new TestInput("""
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

	tester.equal 244, new TestInput("""
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

	tester.equal 280, new TestInput("""
			abc

			def
			"""), [
			'123',
			'456',
			]

	)()

# ---------------------------------------------------------------------------
# --- Test #include

tester.equal 294, new StringInput("""
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

setUnitTesting(false)
tester.equal 308, new StringInput("""
		abc
			#include title.md
		def
		"""), [
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

	tester.equal 344, new TestInput("""
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
	simple.equal 376, line, 'p a paragraph'
	line = oInput.get()
	simple.equal 378, line, 'div:markdown'
	simple.equal 379, block, 'Contents of title.md'
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
	oInput = new TestParser(text)
	line = oInput.get()
	simple.equal 401, line, 'p a paragraph'

	line = oInput.get()
	simple.equal 404, line, 'div:markdown'

	simple.equal 406, block, '\ttitle\n\t====='

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

	oInput = new StringInput(text)

	setUnitTesting(false)
	tester.equal 438, oInput, [
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
