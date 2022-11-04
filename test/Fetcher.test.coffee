# Fetcher.test.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {UnitTester, utest} from '@jdeighan/unit-tester'
import {
	undef, pass, defined, rtrim, replaceVars,
	} from '@jdeighan/coffee-utils'
import {
	arrayToBlock, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher("c:/Users/johnd/mapper/package.json")
	utest.like 21, fetcher.hSourceInfo, {
		filename: 'package.json'
		dir: 'c:/Users/johnd/mapper'
		ext: '.json'
		}
	)()

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher(undef, ['line1', 'line2', 'line3'])

	utest.like 34, node1 = fetcher.fetch(), {str: 'line1', level: 0, lineNum: 1}
	utest.equal 35, fetcher.lineNum, 1
	utest.succeeds 36, () -> fetcher.unfetch(node1)
	utest.equal 37, fetcher.lineNum, 0
	utest.like 38, fetcher.fetch(), {str: 'line1', lineNum: 1}
	utest.like 39, fetcher.fetch(), {str: 'line2', level: 0, lineNum: 2}
	utest.equal 40, fetcher.lineNum, 2
	utest.like 41, fetcher.fetch(), {str: 'line3', level: 0, lineNum: 3}
	utest.equal 42, fetcher.lineNum, 3
	utest.equal 43, fetcher.fetch(), undef
	utest.equal 44, fetcher.lineNum, 3
	utest.equal 45, fetcher.fetch(), undef
	utest.equal 46, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Test TAB indentation

(() ->

	fetcher = new Fetcher(import.meta.url, [
		'line1'
		'\tline2'
		'\t\tline3'
		])

	utest.like 60, node1 = fetcher.fetch(), {
		lineNum: 1
		str: 'line1'
		level: 0
		}
	utest.equal 65, fetcher.lineNum, 1
	utest.succeeds 66, () -> fetcher.unfetch(node1)
	utest.equal 67, fetcher.lineNum, 0
	utest.like 68, fetcher.fetch(), {
		lineNum: 1
		str: 'line1'
		level: 0
		}
	utest.like 73, fetcher.fetch(), {
		lineNum: 2
		str: 'line2'
		level: 1
		}
	utest.equal 78, fetcher.lineNum, 2
	utest.like 79, fetcher.fetch(), {
		lineNum: 3
		str: 'line3'
		level: 2
		}
	utest.equal 84, fetcher.lineNum, 3
	utest.equal 85, fetcher.fetch(), undef
	utest.equal 86, fetcher.lineNum, 3
	utest.equal 87, fetcher.fetch(), undef
	utest.equal 88, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Test space indentation

(() ->

	fetcher = new Fetcher(import.meta.url, [
		'line1'
		'   line2'
		'      line3'
		])

	utest.like 102, node1 = fetcher.fetch(), {
		lineNum: 1
		str: 'line1'
		level: 0
		}
	utest.equal 107, fetcher.lineNum, 1
	utest.succeeds 108, () -> fetcher.unfetch(node1)
	utest.equal 109, fetcher.lineNum, 0
	utest.like 110, fetcher.fetch(), {
		lineNum: 1
		str: 'line1'
		level: 0
		}
	utest.like 115, fetcher.fetch(), {
		lineNum: 2
		str: 'line2'
		level: 1
		}
	utest.equal 120, fetcher.lineNum, 2
	utest.like 121, fetcher.fetch(), {
		lineNum: 3
		str: 'line3'
		level: 2
		}
	utest.equal 126, fetcher.lineNum, 3
	utest.equal 127, fetcher.fetch(), undef
	utest.equal 128, fetcher.lineNum, 3
	utest.equal 129, fetcher.fetch(), undef
	utest.equal 130, fetcher.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# Test __END__

(() ->

	fetcher = new Fetcher(undef, ['abc','def','__END__','ghi'])
	utest.like 139, fetcher.fetch(), {str: 'abc', lineNum: 1}
	utest.like 140, fetcher.fetch(), {str: 'def', lineNum: 2}
	utest.equal 141, fetcher.fetch(), undef
	utest.equal 142, fetcher.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# Test removing trailing WS

(() ->

	fetcher = new Fetcher(undef, ['abc  ','def  '])
	utest.like 151, fetcher.fetch(), {str: 'abc', lineNum: 1}
	utest.like 152, fetcher.fetch(), {str: 'def', lineNum: 2}
	)()

# ---------------------------------------------------------------------------
# Test all(), allUntil(),
#      fetchAll(), fetchUntil(),
#      fetchBlock(), fetchBlockUntil

(() ->
	lItems = [
		'abc'
		'def'
		'ghi'
		]

	func = (hNode) -> return (hNode.str == 'def')

	fetcher = new Fetcher(import.meta.url, lItems)
	utest.like 170, Array.from(fetcher.all()), [
		{str: 'abc', lineNum: 1}
		{str: 'def', lineNum: 2}
		{str: 'ghi', lineNum: 3}
		]

	utest.like 176, fetcher.fetch(), undef

	# ..........................................................

	fetcher = new Fetcher(import.meta.url, lItems)
	utest.like 181, Array.from(fetcher.allUntil(func, 'discardEndLine')), [
		{str: 'abc', lineNum: 1}
		]

	utest.like 185, fetcher.fetch(), {str: 'ghi'}

	fetcher = new Fetcher(import.meta.url, lItems)
	utest.like 188, Array.from(fetcher.allUntil(func, 'keepEndLine')), [
		{str: 'abc', lineNum: 1}
		]

	utest.like 192, fetcher.fetch(), {str: 'def'}

	# ..........................................................

	fetcher = new Fetcher(import.meta.url, lItems)
	utest.like 197, fetcher.fetchBlock(), """
			abc
			def
			ghi
			"""

	fetcher = new Fetcher(import.meta.url, lItems)
	utest.like 204, fetcher.fetchBlockUntil(func, 'discardEndLine'), """
		abc
		"""

	utest.like 208, fetcher.fetch(), {str: 'ghi'}

	fetcher = new Fetcher(import.meta.url, lItems)
	utest.like 211, fetcher.fetchBlockUntil(func, 'keepEndLine'), """
		abc
		"""

	utest.like 215, fetcher.fetch(), {str: 'def'}

	)()

# ---------------------------------------------------------------------------
#     Same tests, but input is a block
# ---------------------------------------------------------------------------

(() ->
	block = """
			abc
			def
			ghi
			"""

	func = (hNode) -> return (hNode.str == 'def')

	fetcher = new Fetcher(import.meta.url, block)
	utest.like 233, Array.from(fetcher.all()), [
		{str: 'abc', lineNum: 1}
		{str: 'def', lineNum: 2}
		{str: 'ghi', lineNum: 3}
		]

	utest.like 239, fetcher.fetch(), undef

	# ..........................................................

	fetcher = new Fetcher(import.meta.url, block)
	utest.like 244, Array.from(fetcher.allUntil(func, 'discardEndLine')), [
		{str: 'abc', lineNum: 1}
		]

	utest.like 248, fetcher.fetch(), {str: 'ghi'}

	fetcher = new Fetcher(import.meta.url, block)
	utest.like 251, Array.from(fetcher.allUntil(func, 'keepEndLine')), [
		{str: 'abc', lineNum: 1}
		]

	utest.like 255, fetcher.fetch(), {str: 'def'}

	# ..........................................................

	fetcher = new Fetcher(import.meta.url, block)
	utest.like 260, fetcher.fetchBlock(), """
			abc
			def
			ghi
			"""

	fetcher = new Fetcher(import.meta.url, block)
	utest.like 267, fetcher.fetchBlockUntil(func, 'discardEndLine'), """
		abc
		"""

	utest.like 271, fetcher.fetch(), {str: 'ghi'}

	fetcher = new Fetcher(import.meta.url, block)
	utest.like 274, fetcher.fetchBlockUntil(func, 'keepEndLine'), """
		abc
		"""

	utest.like 278, fetcher.fetch(), {str: 'def'}

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

	myTester = new MyTester()

	myTester.equal 308, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	utest.equal 319, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
				#include title.md
			def
			""")

	utest.equal 332, fetcher.fetchBlock(), """
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

	utest.like 354, hLine, {str: '=====', lineNum: 2}
	utest.equal 355, fetcher.altInput.hSourceInfo.filename, 'title.md'
	utest.equal 356, fetcher.altInput.lineNum, 2
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

	utest.like 373, hLine, {
		str: '====='
		level: 1
		lineNum: 2
		}
	utest.equal 378, fetcher.altInput.hSourceInfo.filename, 'title.md'
	utest.equal 379, fetcher.altInput.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test @sourceInfoStr

(() ->

	fetcher = new Fetcher('test.txt', """
			abc
			#include title.md
			def
			""")
	utest.equal 392, fetcher.sourceInfoStr(), "test.txt/0"

	hLine = fetcher.fetch()
	utest.equal 395, hLine.str, 'abc'
	utest.equal 396, fetcher.sourceInfoStr(), "test.txt/1"

	hLine = fetcher.fetch()
	utest.equal 399, hLine.str, 'title'
	utest.equal 400, fetcher.sourceInfoStr(), "test.txt/2 title.md/1"

	hLine = fetcher.fetch()
	utest.equal 403, hLine.str, '====='
	utest.equal 404, fetcher.sourceInfoStr(), "test.txt/2 title.md/2"

	hLine = fetcher.fetch()
	utest.equal 407, hLine.str, 'def'
	utest.equal 408, fetcher.sourceInfoStr(), "test.txt/3"
	)()
