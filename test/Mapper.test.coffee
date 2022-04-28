# Mapper.test.coffee

import assert from 'assert'

import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {
	undef, pass, isEmpty, isString,
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
		- getPair(), peekPair(), ungetPair(), skipPair()
		- overriding of mapLine() to return alternate strings or objects
		- fetch() and fetchBlock() inside mapLine()
###

# ---------------------------------------------------------------------------
# --- test getPair(), peekPair(), ungetPair(), skipPair()

(() ->
	input = new Mapper(import.meta.url, """
			abc
				def
					ghi
			""")

	# --- lPair is [item, level]

	lPair = input.peekPair()
	simple.equal 41, lPair, ['abc', 0]

	lPair = input.peekPair()
	simple.equal 44, lPair, ['abc', 0]

	lPair = input.getPair()
	simple.equal 47, lPair, ['abc', 0]

	lPair = input.getPair()
	simple.equal 50, lPair, ['def', 1]

	input.ungetPair(lPair)
	lPair = input.getPair()
	simple.equal 54, lPair, ['def', 1]

	lPair = input.getPair()
	simple.equal 57, lPair, ['ghi', 2]
	input.ungetPair(lPair)

	input.skipPair()
	pair = input.getPair()
	simple.equal 62, pair, undef

	)()

# ---------------------------------------------------------------------------

class MapperTester extends UnitTester

	transformValue: (input) ->
		# --- input may be a string or a Mapper or subclass

		if isString(input)
			oInput = new Mapper(import.meta.url, input)
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

	tester.equal 120, new TestMapper(import.meta.url, str), """
			abc
			def
			"""

	simple.equal 125, doMap(TestMapper, import.meta.url, str), """
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

	tester.equal 144, new TestMapper(import.meta.url, """
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

	class TestMapper extends Mapper

		# --- Remove blank lines PLUS the line following a blank line
		mapLine: (line, level) ->
			if line == ''
				follow = @fetch()
				return undef
			else
				return line

	tester.equal 170, new TestMapper(import.meta.url, """
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

	class TestMapper extends Mapper

		mapLine: (line, level) ->

			debug "enter mapLine('#{line}', #{level})"
			if line == '' || line.match(/^\s*\#($|\s)/)
				debug "return undef from mapLine()"
				return undef     # skip comments and blank lines

			while (str = @fetch())? && (indentLevel(str) >= level+2)
				line += ' ' + undented(str)
			debug "return from mapLine()", line
			return line

	tester.equal 200, new TestMapper(import.meta.url, """
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

	tester.equal 236, new TestMapper(import.meta.url, """
			abc

			def
			"""), """
			123
			456
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test #include

tester.equal 250, """
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
#        - skipPair comments and blank lines
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

	tester.equal 287, new TestMapper(import.meta.url, """
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

	oInput = new TestParser(import.meta.url, text)
	lPair = oInput.getPair()
	simple.equal 321, lPair[0], 'p a paragraph'
	lPair = oInput.getPair()
	simple.equal 323, lPair[0], 'div:markdown'
	simple.equal 324, block, '\ttitle\n\t====='
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

	oInput = new TestParser(import.meta.url, """
			p a paragraph
			div:markdown
				line 1

				line 3
			""")
	lPair = oInput.getPair()
	simple.equal 348, lPair[0], 'p a paragraph'
	lPair = oInput.getPair()
	simple.equal 350, lPair[0], 'div:markdown'
	simple.equal 351, block, """
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

	oInput = new TestParser(import.meta.url, text)
	lPair = oInput.getPair()
	simple.equal 377, lPair[0], 'p a paragraph'

	lPair = oInput.getPair()
	simple.equal 380, lPair[0], 'div:markdown'

	simple.equal 382, block, '\ttitle\n\t====='
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

	tester.equal 408, text, """
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

tester.equal 422, """
		abc

		# --- this is a comment

		def
		""", """
		abc

		# --- this is a comment

		def
		"""

# ---------------------------------------------------------------------------
# --- Test using getAllPairs(), i.e. retrieving non-text

(()->

	class GatherTester2 extends UnitTesterNorm

		transformValue: (oInput) ->

			assert oInput instanceof Mapper,
				"oInput should be a Mapper object"
			return oInput.getAllPairs()

	tester2 = new GatherTester2()

	cmdRE = ///^
			\s*                # skipPair leading whitespace
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

	tester2.equal 467, new TestMapper2(import.meta.url, """
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
