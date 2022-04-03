# Mapper.test.coffee

import assert from 'assert'

import {UnitTester} from '@jdeighan/unit-tester'
import {
	undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {
	debug, debugging, setDebugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {Mapper} from '@jdeighan/mapper'

dir = mydir(`import.meta.url`)
process.env.DIR_MARKDOWN = mkpath(dir, 'markdown')

simple = new UnitTester()

###
	class Mapper should handle the following:
		- #include <file> statements
		- get(), peek(), unget(), skip()
		- overriding of mapLine() to return alternate strings or objects
		- fetch() and fetchBlock() inside mapLine()
###

# ---------------------------------------------------------------------------
# --- test get(), peek(), unget(), skip()

(() ->
	input = new Mapper("""
			abc
				def
					ghi
			""")

	# --- lPair is [item, level]

	lPair = input.peek()
	simple.equal 44, lPair, ['abc', 0]

	lPair = input.peek()
	simple.equal 47, lPair, ['abc', 0]

	lPair = input.get()
	simple.equal 50, lPair, ['abc', 0]

	lPair = input.get()
	simple.equal 53, lPair, ['def', 1]

	input.unget(lPair)
	lPair = input.get()
	simple.equal 57, lPair, ['def', 1]

	lPair = input.get()
	simple.equal 60, lPair, ['ghi', 2]
	input.unget(lPair)

	input.skip()
	pair = input.get()
	simple.equal 65, pair, undef

	)()

# ---------------------------------------------------------------------------

class GatherTester extends UnitTester

	transformValue: (oInput) ->

		assert oInput instanceof Mapper,
			"oInput should be a Mapper object"
		return oInput.getBlock()

	normalize: (str) ->
		return str

tester = new GatherTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 87, new Mapper("""
		abc
		def
		"""), """
		abc
		def
		"""

tester.equal 95, new Mapper("""
		abc

		def
		"""), """
		abc

		def
		"""

(() ->
	class TestInput extends Mapper

		# --- This removes blank lines
		mapLine: (line, level) ->
			if line == ''
				return undef
			else
				return line

	tester.equal 115, new TestInput("""
			abc

			def
			"""), """
			abc
			def
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test basic use of mapping function

(()->
	class TestInput extends Mapper

		# --- This maps all non-empty lines to the string 'x'
		mapLine: (line, level) ->
			if line == ''
				return undef
			else
				return 'x'

	tester.equal 138, new TestInput("""
			abc

			def
			"""), """
			x
			x
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test ability to access 'this' object from a mapper
#     Goal: remove not only blank lines, but also the line following

(()->

	class TestInput extends Mapper

		# --- Remove blank lines PLUS the line following a blank line
		mapLine: (line, level) ->
			if line == ''
				follow = @fetch()
				return undef
			else
				return line

	tester.equal 164, new TestInput("""
			abc

			def
			ghi
			"""), """
			abc
			ghi
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test implementing continuation lines

(()->

	class TestInput extends Mapper

		mapLine: (line, level) ->

			if line == '' || isComment(line)
				return undef     # skip comments and blank lines

			while (@lBuffer.length > 0) \
					&& (indentLevel(@lBuffer[0]) >= level+2)
				next = @lBuffer.shift()
				line += ' ' + undented(next)
			return line

	tester.equal 193, new TestInput("""
			str = compare(
					"abcde",
					expected
					)

			call func
					with multiple
					long parameters

			# --- DONE ---
			"""), """
			str = compare( "abcde", expected )
			call func with multiple long parameters
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test overriding the class

(()->

	class TestInput extends Mapper

		mapLine: (line, level) ->

			if isEmpty(line)
				return undef
			if line == 'abc'
				return '123'
			else if line == 'def'
				return '456'
			else
				return line

	tester.equal 229, new TestInput("""
			abc

			def
			"""), """
			123
			456
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test #include

tester.equal 243, new Mapper("""
		abc
			#include title.md
		def
		"""), """
		abc
			title
			=====
		def
		"""

# ---------------------------------------------------------------------------
# --- Test advanced use of mapping function
#        - skip comments and blank lines
#        - replace reactive statements

(()->
	class TestInput extends Mapper

		mapLine: (line, level) ->

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
				[_, varName, expr] = lMatches
				return "`$:{\n#{varName} = #{expr}\n}`"
			else
				return line

	tester.equal 280, new TestInput("""
			abc
			myvar    <==     2 * 3

			def
			"""), """
			abc
			`$:{
			myvar = 2 * 3
			}`
			def
			"""
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
	class TestParser extends Mapper

		mapLine: (line, level) ->
			if line == 'div:markdown'
				block = @fetchBlock(1)
			return line

	oInput = new TestParser(text)
	lPair = oInput.get()
	simple.equal 314, lPair[0], 'p a paragraph'
	lPair = oInput.get()
	simple.equal 316, lPair[0], 'div:markdown'
	simple.equal 317, block, '\ttitle\n\t====='
	)()

# ---------------------------------------------------------------------------
# --- Test blank lines inside a block

(() ->
	block = undef
	class TestParser extends Mapper

		mapLine: (line, level) ->

			if line == 'div:markdown'
				block = @fetchBlock(1)
			return line

	oInput = new TestParser("""
			p a paragraph
			div:markdown
				line 1

				line 3
			""")
	lPair = oInput.get()
	simple.equal 341, lPair[0], 'p a paragraph'
	lPair = oInput.get()
	simple.equal 343, lPair[0], 'div:markdown'
	simple.equal 344, block, """
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
	class TestParser extends Mapper

		mapLine: (line, level) ->

			if line == 'div:markdown'
				block = @fetchBlock(1)
			return line

	oInput = new TestParser(text)
	lPair = oInput.get()
	simple.equal 370, lPair[0], 'p a paragraph'

	lPair = oInput.get()
	simple.equal 373, lPair[0], 'div:markdown'

	simple.equal 375, block, '\ttitle\n\t====='
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

	oInput = new Mapper(text)

	tester.equal 403, oInput, """
		p a paragraph
		div:markdown
			header
			======

				para
				----
		"""
	)()

# ---------------------------------------------------------------------------
# --- Test comment

tester.equal 417, new Mapper("""
		abc

		# --- this is a comment

		def
		"""), """
		abc

		# --- this is a comment

		def
		"""

# ---------------------------------------------------------------------------
# --- Test using getAll(), i.e. retrieving non-text

(()->

	class GatherTester2 extends UnitTester

		transformValue: (oInput) ->

			assert oInput instanceof Mapper,
				"oInput should be a Mapper object"
			return oInput.getAll()

	tester2 = new GatherTester2()

	cmdRE = ///^
			\s*                # skip leading whitespace
			\# ([a-z][a-z_]*)  # command name
			\s*                # skipwhitespace following command
			(.*)               # command arguments
			$///

	class TestInput2 extends Mapper

		mapLine: (line, level) ->
			lMatches = line.match(cmdRE)
			if lMatches?
				return { cmd: lMatches[1], argstr: lMatches[2] }
			else
				return line

	tester2.equal 462, new TestInput2("""
			abc
			#if x==y
				def
			#else
				ghi
			"""), [
			['abc', 0],
			[{ cmd: 'if', argstr: 'x==y' }, 0],
			['def', 1],
			[{ cmd: 'else', argstr: '' }, 0],
			['ghi', 1],
			]
	)()
