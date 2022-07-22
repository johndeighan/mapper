# Fetcher.test.coffee

import assert from 'assert'

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {
	undef, pass, defined, error, warn, rtrim, replaceVars,
	} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {
	arrayToBlock, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher("c:/Users/johnd/mapper/package.json")
	simple.equal 22, fetcher.hSourceInfo.filename, 'package.json'
	simple.equal 23, fetcher.hSourceInfo.dir, 'c:/Users/johnd/mapper'
	simple.equal 24, fetcher.hSourceInfo.ext, '.json'
	)()

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher(undef, ['line1', 'line2', 'line3'])

	simple.like 33, fetcher.fetch(), {line: 'line1', lineNum: 1}
	simple.equal 34, fetcher.lineNum, 1
	simple.succeeds 35, () -> fetcher.unfetch({line: 'line1', lineNum: 1})
	simple.equal 36, fetcher.lineNum, 0
	simple.like 37, fetcher.fetch(), {line: 'line1', lineNum: 1}
	simple.like 38, fetcher.fetch(), {line: 'line2', lineNum: 2}
	simple.equal 39, fetcher.lineNum, 2
	simple.like 40, fetcher.fetch(), {line: 'line3', lineNum: 3}
	simple.equal 41, fetcher.lineNum, 3
	simple.equal 42, fetcher.fetch(), undef
	simple.equal 43, fetcher.lineNum, 3
	simple.equal 44, fetcher.fetch(), undef
	simple.equal 45, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Test TAB indentation

(() ->

	fetcher = new Fetcher(import.meta.url, [
		'line1'
		'\tline2'
		'\t\tline3'
		])

	simple.like 33, fetcher.fetch(), {
		line: 'line1'
		lineNum: 1
		prefix: ''
		str: 'line1'
		level: 0
		}
	simple.equal 34, fetcher.lineNum, 1
	simple.succeeds 35, () -> fetcher.unfetch({
		line: 'line1'
		lineNum: 1
		prefix: ''
		str: 'line1'
		level: 0
		})
	simple.equal 36, fetcher.lineNum, 0
	simple.like 37, fetcher.fetch(), {
		line: 'line1'
		lineNum: 1
		prefix: ''
		str: 'line1'
		level: 0
		}
	simple.like 38, fetcher.fetch(), {
		line: '\tline2'
		lineNum: 2
		prefix: "\t"
		str: 'line2'
		level: 1
		}
	simple.equal 39, fetcher.lineNum, 2
	simple.like 40, fetcher.fetch(), {
		line: '\t\tline3'
		lineNum: 3
		prefix: "\t\t"
		str: 'line3'
		level: 2
		}
	simple.equal 41, fetcher.lineNum, 3
	simple.equal 42, fetcher.fetch(), undef
	simple.equal 43, fetcher.lineNum, 3
	simple.equal 44, fetcher.fetch(), undef
	simple.equal 45, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Test space indentation

(() ->

	fetcher = new Fetcher(import.meta.url, [
		'line1'
		'   line2'
		'      line3'
		])

	simple.like 33, fetcher.fetch(), {
		line: 'line1'
		lineNum: 1
		prefix: ''
		str: 'line1'
		level: 0
		}
	simple.equal 34, fetcher.lineNum, 1
	simple.succeeds 35, () -> fetcher.unfetch({
		line: 'line1'
		lineNum: 1
		prefix: ''
		str: 'line1'
		level: 0
		})
	simple.equal 36, fetcher.lineNum, 0
	simple.like 37, fetcher.fetch(), {
		line: 'line1'
		lineNum: 1
		prefix: ''
		str: 'line1'
		level: 0
		}
	simple.like 38, fetcher.fetch(), {
		line: '   line2'
		lineNum: 2
		prefix: "   "
		str: 'line2'
		level: 1
		}
	simple.equal 39, fetcher.lineNum, 2
	simple.like 40, fetcher.fetch(), {
		line: '      line3'
		lineNum: 3
		prefix: "      "
		str: 'line3'
		level: 2
		}
	simple.equal 41, fetcher.lineNum, 3
	simple.equal 42, fetcher.fetch(), undef
	simple.equal 43, fetcher.lineNum, 3
	simple.equal 44, fetcher.fetch(), undef
	simple.equal 45, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# Test prefix option

(() ->
	fetcher = new Fetcher(undef, ['abc','def','ghi'], {prefix: '>'})
	simple.like 53, fetcher.fetch(), {line: '>abc', lineNum: 1}
	simple.like 54, fetcher.fetch(), {line: '>def', lineNum: 2}
	)()

# ---------------------------------------------------------------------------
# Test __END__

(() ->

	fetcher = new Fetcher(undef, ['abc','def','__END__','ghi'])
	simple.like 63, fetcher.fetch(), {line: 'abc', lineNum: 1}
	simple.like 64, fetcher.fetch(), {line: 'def', lineNum: 2}
	simple.equal 65, fetcher.fetch(), undef
	simple.equal 66, fetcher.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# Test removing trailing WS

(() ->

	fetcher = new Fetcher(undef, ['abc  ','def  '], {prefix: '>'})
	simple.like 75, fetcher.fetch(), {line: '>abc', lineNum: 1}
	simple.like 76, fetcher.fetch(), {line: '>def', lineNum: 2}
	)()

# ---------------------------------------------------------------------------
# Test all()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  '], {prefix: '>'})
	lItems = for item from fetcher.all()
		item
	simple.like 86, lItems, [
		{line: '>abc', lineNum: 1}
		{line: '>def', lineNum: 2}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchAll()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.like 97, fetcher.fetchAll(), [
		{line: 'abc', lineNum: 1}
		{line: 'def', lineNum: 2}
		{line: 'ghi', lineNum: 3}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchUntil()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.like 109, fetcher.fetchUntil('def'), [
		{line: 'abc', lineNum: 1}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchBlock()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.equal 119, fetcher.fetchBlock(), """
		abc
		def
		ghi
		"""
	)()

# ---------------------------------------------------------------------------
#     Input is a block
# ---------------------------------------------------------------------------
# Test fetchAll()

(() ->
	fetcher = new Fetcher(undef, """
			abc
			def
			ghi
			""")
	simple.like 137, fetcher.fetchAll(), [
		{line: 'abc', lineNum: 1}
		{line: 'def', lineNum: 2}
		{line: 'ghi', lineNum: 3}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchUntil()

(() ->
	fetcher = new Fetcher(undef, """
			abc
			def
			ghi
			""")
	simple.like 153, fetcher.fetchUntil('def'), [
		{line: 'abc', lineNum: 1}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchBlock()

(() ->
	fetcher = new Fetcher(undef, """
			abc
			def
			ghi
			""")
	simple.equal 167, fetcher.fetchBlock(), """
		abc
		def
		ghi
		"""
	)()

# ---------------------------------------------------------------------------
# --- Test using #include

# ---------------------------------------------------------------------------
# File title.md contains:
# title
# =====
# ---------------------------------------------------------------------------

(() ->

	numLines = undef

	class MyTester extends UnitTester

		transformValue: (block) ->

			fetcher = new Fetcher(import.meta.url, block)
			block = fetcher.fetchBlock()
			numLines = fetcher.lineNum   # set variable numLines
			return block

	# ..........................................................

	tester = new MyTester()

	tester.equal 200, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	simple.equal 211, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->
	fetcher = new Fetcher(import.meta.url, """
			abc
			def
			""", {prefix: '---'})

	simple.equal 222, fetcher.fetchBlock(), """
			---abc
			---def
			"""
	)()

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
				#include title.md
			def
			""")

	simple.equal 238, fetcher.fetchBlock(), """
			abc
				title
				=====
			def
			"""
	)()

# ---------------------------------------------------------------------------
# --- test @hSourceInfo

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
			#include title.md
			def
			""")

	while defined(hLine = fetcher.fetch()) \
			&& (hLine.line != '=====')
		pass

	simple.like 261, hLine, {line: '=====', lineNum: 2}
	simple.equal 263, fetcher.altInput.hSourceInfo.filename, 'title.md'
	simple.equal 264, fetcher.altInput.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test @hSourceInfo with indentation

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
				#include title.md
			def
			""")

	while defined(hLine = fetcher.fetch()) \
			&& (hLine.line != '\t=====')
		pass

	simple.equal 282, hLine.line, '\t====='
	simple.equal 284, fetcher.altInput.hSourceInfo.filename, 'title.md'
	simple.equal 285, fetcher.altInput.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test @sourceInfoStr

(() ->

	fetcher = new Fetcher('test.txt', """
			abc
			#include title.md
			def
			""")
	simple.equal 298, fetcher.sourceInfoStr(), "test.txt/0"

	hLine = fetcher.fetch()
	simple.equal 301, hLine.line, 'abc'
	simple.equal 302, fetcher.sourceInfoStr(), "test.txt/1"

	hLine = fetcher.fetch()
	simple.equal 305, hLine.line, 'title'
	simple.equal 306, fetcher.sourceInfoStr(), "test.txt/2 title.md/1"

	hLine = fetcher.fetch()
	simple.equal 309, hLine.line, '====='
	simple.equal 310, fetcher.sourceInfoStr(), "test.txt/2 title.md/2"

	hLine = fetcher.fetch()
	simple.equal 313, hLine.line, 'def'
	simple.equal 314, fetcher.sourceInfoStr(), "test.txt/3"
	)()
