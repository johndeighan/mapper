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

	fetcher = new Fetcher(undef, [1, 2, 3])

	simple.hashhas 33, fetcher.fetch(), {item: 1, lineNum: 1}
	simple.equal 34, fetcher.lineNum, 1
	simple.succeeds 35, () -> fetcher.unfetch({item: 1, lineNum: 1})
	simple.equal 36, fetcher.lineNum, 0
	simple.hashhas 37, fetcher.fetch(), {item: 1, lineNum: 1}
	simple.hashhas 38, fetcher.fetch(), {item: 2, lineNum: 2}
	simple.equal 39, fetcher.lineNum, 2
	simple.hashhas 40, fetcher.fetch(), {item: 3, lineNum: 3}
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
	simple.hashhas 53, fetcher.fetch(), {item: '>abc', lineNum: 1}
	simple.hashhas 54, fetcher.fetch(), {item: '>def', lineNum: 2}
	)()

# ---------------------------------------------------------------------------
# Test __END__

(() ->

	fetcher = new Fetcher(undef, ['abc','def','__END__','ghi'])
	simple.hashhas 63, fetcher.fetch(), {item: 'abc', lineNum: 1}
	simple.hashhas 64, fetcher.fetch(), {item: 'def', lineNum: 2}
	simple.equal 65, fetcher.fetch(), undef
	simple.equal 66, fetcher.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# Test removing trailing WS

(() ->

	fetcher = new Fetcher(undef, ['abc  ','def  '], {prefix: '>'})
	simple.hashhas 75, fetcher.fetch(), {item: '>abc', lineNum: 1}
	simple.hashhas 76, fetcher.fetch(), {item: '>def', lineNum: 2}
	)()

# ---------------------------------------------------------------------------
# Test all()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  '], {prefix: '>'})
	lItems = for item from fetcher.all()
		item
	simple.hashhas 86, lItems, [
		{item: '>abc', lineNum: 1}
		{item: '>def', lineNum: 2}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchAll()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.hashhas 97, fetcher.fetchAll(), [
		{item: 'abc', lineNum: 1}
		{item: 'def', lineNum: 2}
		{item: 'ghi', lineNum: 3}
		]
	)()

# ---------------------------------------------------------------------------
# Test fetchUntil()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.hashhas 109, fetcher.fetchUntil('def'), [
		{item: 'abc', lineNum: 1}
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
	simple.hashhas 137, fetcher.fetchAll(), [
		{item: 'abc', lineNum: 1}
		{item: 'def', lineNum: 2}
		{item: 'ghi', lineNum: 3}
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
	simple.hashhas 153, fetcher.fetchUntil('def'), [
		{item: 'abc', lineNum: 1}
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

	while defined(hItem = fetcher.fetch()) \
			&& (hItem.item != '=====')
		pass

	simple.hashhas 261, hItem, {item: '=====', lineNum: 2}
	h = fetcher.hSourceInfo
	simple.equal 263, h.altInput.hSourceInfo.filename, 'title.md'
	simple.equal 264, h.altInput.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test @hSourceInfo with indentation

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
				#include title.md
			def
			""")

	while defined(hItem = fetcher.fetch()) \
			&& (hItem.item != '\t=====')
		pass

	simple.equal 282, hItem.item, '\t====='
	altInput = fetcher.hSourceInfo.altInput
	simple.equal 284, altInput.hSourceInfo.filename, 'title.md'
	simple.equal 285, altInput.lineNum, 2
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

	hItem = fetcher.fetch()
	simple.equal 301, hItem.item, 'abc'
	simple.equal 302, fetcher.sourceInfoStr(), "test.txt/1"

	hItem = fetcher.fetch()
	simple.equal 305, hItem.item, 'title'
	simple.equal 306, fetcher.sourceInfoStr(), "test.txt/2 title.md/1"

	hItem = fetcher.fetch()
	simple.equal 309, hItem.item, '====='
	simple.equal 310, fetcher.sourceInfoStr(), "test.txt/2 title.md/2"

	hItem = fetcher.fetch()
	simple.equal 313, hItem.item, 'def'
	simple.equal 314, fetcher.sourceInfoStr(), "test.txt/3"
	)()
