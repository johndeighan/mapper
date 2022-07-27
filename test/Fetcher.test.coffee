# Fetcher.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, defined, rtrim, replaceVars,
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
	simple.like 22, fetcher.hSourceInfo, {
		filename: 'package.json'
		dir: 'c:/Users/johnd/mapper'
		ext: '.json'
		}
	)()

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher(undef, ['line1', 'line2', 'line3'])

	simple.like 35, node1 = fetcher.fetch(), {str: 'line1', level: 0, lineNum: 1}
	simple.equal 36, fetcher.lineNum, 1
	simple.succeeds 37, () -> fetcher.unfetch(node1)
	simple.equal 38, fetcher.lineNum, 0
	simple.like 39, fetcher.fetch(), {str: 'line1', lineNum: 1}
	simple.like 40, fetcher.fetch(), {str: 'line2', level: 0, lineNum: 2}
	simple.equal 41, fetcher.lineNum, 2
	simple.like 42, fetcher.fetch(), {str: 'line3', level: 0, lineNum: 3}
	simple.equal 43, fetcher.lineNum, 3
	simple.equal 44, fetcher.fetch(), undef
	simple.equal 45, fetcher.lineNum, 3
	simple.equal 46, fetcher.fetch(), undef
	simple.equal 47, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Test TAB indentation

(() ->

	fetcher = new Fetcher(import.meta.url, [
		'line1'
		'\tline2'
		'\t\tline3'
		])

	simple.like 61, node1 = fetcher.fetch(), {
		lineNum: 1
		str: 'line1'
		level: 0
		}
	simple.equal 66, fetcher.lineNum, 1
	simple.succeeds 67, () -> fetcher.unfetch(node1)
	simple.equal 72, fetcher.lineNum, 0
	simple.like 73, fetcher.fetch(), {
		lineNum: 1
		str: 'line1'
		level: 0
		}
	simple.like 78, fetcher.fetch(), {
		lineNum: 2
		str: 'line2'
		level: 1
		}
	simple.equal 83, fetcher.lineNum, 2
	simple.like 84, fetcher.fetch(), {
		lineNum: 3
		str: 'line3'
		level: 2
		}
	simple.equal 89, fetcher.lineNum, 3
	simple.equal 90, fetcher.fetch(), undef
	simple.equal 91, fetcher.lineNum, 3
	simple.equal 92, fetcher.fetch(), undef
	simple.equal 93, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Test space indentation

(() ->

	fetcher = new Fetcher(import.meta.url, [
		'line1'
		'   line2'
		'      line3'
		])

	simple.like 107, node1 = fetcher.fetch(), {
		lineNum: 1
		str: 'line1'
		level: 0
		}
	simple.equal 112, fetcher.lineNum, 1
	simple.succeeds 113, () -> fetcher.unfetch(node1)
	simple.equal 118, fetcher.lineNum, 0
	simple.like 119, fetcher.fetch(), {
		lineNum: 1
		str: 'line1'
		level: 0
		}
	simple.like 124, fetcher.fetch(), {
		lineNum: 2
		str: 'line2'
		level: 1
		}
	simple.equal 129, fetcher.lineNum, 2
	simple.like 130, fetcher.fetch(), {
		lineNum: 3
		str: 'line3'
		level: 2
		}
	simple.equal 135, fetcher.lineNum, 3
	simple.equal 136, fetcher.fetch(), undef
	simple.equal 137, fetcher.lineNum, 3
	simple.equal 138, fetcher.fetch(), undef
	simple.equal 139, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# Test __END__

(() ->

	fetcher = new Fetcher(undef, ['abc','def','__END__','ghi'])
	simple.like 148, fetcher.fetch(), {str: 'abc', lineNum: 1}
	simple.like 149, fetcher.fetch(), {str: 'def', lineNum: 2}
	simple.equal 150, fetcher.fetch(), undef
	simple.equal 151, fetcher.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# Test removing trailing WS

(() ->

	fetcher = new Fetcher(undef, ['abc  ','def  '])
	simple.like 160, fetcher.fetch(), {str: 'abc', lineNum: 1}
	simple.like 161, fetcher.fetch(), {str: 'def', lineNum: 2}
	)()

# ---------------------------------------------------------------------------
# Test all()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  '])
	lItems = for item from fetcher.all()
		item
	simple.like 171, lItems, [
		{str: 'abc', lineNum: 1}
		{str: 'def', lineNum: 2}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchAll()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.like 182, fetcher.fetchAll(), [
		{str: 'abc', lineNum: 1}
		{str: 'def', lineNum: 2}
		{str: 'ghi', lineNum: 3}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchUntil()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.like 194, fetcher.fetchUntil('def'), [
		{str: 'abc', lineNum: 1}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchBlock()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.equal 204, fetcher.fetchBlock(), """
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
	simple.like 222, fetcher.fetchAll(), [
		{str: 'abc', lineNum: 1}
		{str: 'def', lineNum: 2}
		{str: 'ghi', lineNum: 3}
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
	simple.like 238, fetcher.fetchUntil('def'), [
		{str: 'abc', lineNum: 1}
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
	simple.equal 252, fetcher.fetchBlock(), """
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

	tester.equal 285, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	simple.equal 296, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
				#include title.md
			def
			""")

	simple.equal 309, fetcher.fetchBlock(), """
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

	while defined(hLine = fetcher.fetch()) && (hLine.str != '=====')
		pass

	simple.like 332, hLine, {str: '=====', lineNum: 2}
	simple.equal 333, fetcher.altInput.hSourceInfo.filename, 'title.md'
	simple.equal 334, fetcher.altInput.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test @hSourceInfo with indentation

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
				#include title.md
			def
			""")

	while defined(hLine = fetcher.fetch()) && (hLine.str != '=====')
		pass

	simple.like 350, hLine, {
		str: '====='
		level: 1
		lineNum: 2
		}
	simple.equal 353, fetcher.altInput.hSourceInfo.filename, 'title.md'
	simple.equal 354, fetcher.altInput.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test @sourceInfoStr

(() ->

	fetcher = new Fetcher('test.txt', """
			abc
			#include title.md
			def
			""")
	simple.equal 367, fetcher.sourceInfoStr(), "test.txt/0"

	hLine = fetcher.fetch()
	simple.equal 370, hLine.str, 'abc'
	simple.equal 371, fetcher.sourceInfoStr(), "test.txt/1"

	hLine = fetcher.fetch()
	simple.equal 374, hLine.str, 'title'
	simple.equal 375, fetcher.sourceInfoStr(), "test.txt/2 title.md/1"

	hLine = fetcher.fetch()
	simple.equal 378, hLine.str, '====='
	simple.equal 379, fetcher.sourceInfoStr(), "test.txt/2 title.md/2"

	hLine = fetcher.fetch()
	simple.equal 382, hLine.str, 'def'
	simple.equal 383, fetcher.sourceInfoStr(), "test.txt/3"
	)()
