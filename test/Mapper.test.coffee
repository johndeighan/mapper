# Mapper.test.coffee

import assert from 'assert'

import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {
	undef, pass, isEmpty, isComment, isString,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {
	debug, setDebugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {Mapper, doMap} from '@jdeighan/mapper'

simple = new UnitTesterNorm()

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
			""", import.meta.url)

	# --- lPair is [item, level]

	lPair = input.peek()
	simple.equal 41, lPair, ['abc', 0]

	lPair = input.peek()
	simple.equal 44, lPair, ['abc', 0]

	lPair = input.get()
	simple.equal 47, lPair, ['abc', 0]

	lPair = input.get()
	simple.equal 50, lPair, ['def', 1]

	input.unget(lPair)
	lPair = input.get()
	simple.equal 54, lPair, ['def', 1]

	lPair = input.get()
	simple.equal 57, lPair, ['ghi', 2]
	input.unget(lPair)

	input.skip()
	pair = input.get()
	simple.equal 62, pair, undef

	)()

# ---------------------------------------------------------------------------

class MapperTester extends UnitTester

	transformValue: (input) ->
		# --- input may be a string or a Mapper or subclass

		if isString(input)
			oInput = new Mapper(input, import.meta.url)
		else
			assert input instanceof Mapper,
				"input should be a Mapper object"
			oInput = input
		return oInput.getBlock()

tester = new MapperTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 86, """
		abc
		def
		""", """
		abc
		def
		"""

tester.equal 94, """
		abc

		def
		""", """
		abc

		def
		"""

(() ->
	class TestMapper extends Mapper

		# --- This removes blank lines
		mapLine: (line, level) ->
			if line == ''
				return undef
			else
				return line

	str = """
			abc

			def
			"""

	tester.equal 120, new TestMapper(str, import.meta.url), """
			abc
			def
			"""

	simple.equal 125, doMap(TestMapper, str, import.meta.url), """
			abc
			def
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test basic use of mapping function

(()->
	class TestMapper extends Mapper

		# --- This maps all non-empty lines to the string 'x'
		mapLine: (line, level) ->
			if line == ''
				return undef
			else
				return 'x'

	tester.equal 144, new TestMapper("""
			abc

			def
			""", import.meta.url), """
			x
			x
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test ability to access 'this' object from a mapper
#     Goal: remove not only blank lines, but also the line following

(()->

	class TestMapper extends Mapper

		# --- Remove blank lines PLUS the line following a blank line
		mapLine: (line, level) ->
			if line == ''
				follow = @fetch()
				return undef
			else
				return line

	tester.equal 170, new TestMapper("""
			abc

			def
			ghi
			""", import.meta.url), """
			abc
			ghi
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test implementing continuation lines

(()->

	class TestMapper extends Mapper

		mapLine: (line, level) ->

			if line == '' || isComment(line)
				return undef     # skip comments and blank lines

			while (@lBuffer.length > 0) \
					&& (indentLevel(@lBuffer[0]) >= level+2)
				next = @lBuffer.shift()
				line += ' ' + undented(next)
			return line

	tester.equal 199, new TestMapper("""
			str = compare(
					"abcde",
					expected
					)

			call func
					with multiple
					long parameters

			# --- DONE ---
			""", import.meta.url), """
			str = compare( "abcde", expected )
			call func with multiple long parameters
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test overriding the class

(()->

	class TestMapper extends Mapper

		mapLine: (line, level) ->

			if isEmpty(line)
				return undef
			if line == 'abc'
				return '123'
			else if line == 'def'
				return '456'
			else
				return line

	tester.equal 235, new TestMapper("""
			abc

			def
			""", import.meta.url), """
			123
			456
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test #include

tester.equal 249, """
		abc
			#include title.md
		def
		""", """
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
	class TestMapper extends Mapper

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

	tester.equal 286, new TestMapper("""
			abc
			myvar    <==     2 * 3

			def
			""", import.meta.url), """
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

	oInput = new TestParser(text, import.meta.url)
	lPair = oInput.get()
	simple.equal 320, lPair[0], 'p a paragraph'
	lPair = oInput.get()
	simple.equal 322, lPair[0], 'div:markdown'
	simple.equal 323, block, '\ttitle\n\t====='
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
			""", import.meta.url)
	lPair = oInput.get()
	simple.equal 347, lPair[0], 'p a paragraph'
	lPair = oInput.get()
	simple.equal 349, lPair[0], 'div:markdown'
	simple.equal 350, block, """
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

	oInput = new TestParser(text, import.meta.url)
	lPair = oInput.get()
	simple.equal 376, lPair[0], 'p a paragraph'

	lPair = oInput.get()
	simple.equal 379, lPair[0], 'div:markdown'

	simple.equal 381, block, '\ttitle\n\t====='
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

	tester.equal 409, text, """
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

tester.equal 423, """
		abc

		# --- this is a comment

		def
		""", """
		abc

		# --- this is a comment

		def
		"""

# ---------------------------------------------------------------------------
# --- Test using getAll(), i.e. retrieving non-text

(()->

	class GatherTester2 extends UnitTesterNorm

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

	class TestMapper2 extends Mapper

		mapLine: (line, level) ->
			lMatches = line.match(cmdRE)
			if lMatches?
				return { cmd: lMatches[1], argstr: lMatches[2] }
			else
				return line

	tester2.equal 468, new TestMapper2("""
			abc
			#if x==y
				def
			#else
				ghi
			""", import.meta.url), [
			['abc', 0],
			[{ cmd: 'if', argstr: 'x==y' }, 0],
			['def', 1],
			[{ cmd: 'else', argstr: '' }, 0],
			['ghi', 1],
			]
	)()
