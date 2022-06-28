# Fetcher.test.coffee

import assert from 'assert'

import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {
	undef, pass, defined, error, warn, rtrim, replaceVars,
	} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {
	arrayToBlock, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Fetcher} from '@jdeighan/mapper/fetcher'

simple = new UnitTester()

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher("c:/Users/johnd/mapper/package.json")
	simple.equal 24, fetcher.hSourceInfo.filename, 'package.json'
	simple.equal 25, fetcher.hSourceInfo.dir, 'c:/Users/johnd/mapper'
	simple.equal 26, fetcher.hSourceInfo.ext, '.json'
	)()

# ---------------------------------------------------------------------------

(() ->

	fetcher = new Fetcher(undef, [1, 2, 3])

	simple.equal 35, fetcher.fetch(), 1
	simple.equal 36, fetcher.hSourceInfo.lineNum, 1
	simple.succeeds 37, () -> fetcher.unfetch(1)
	simple.equal 38, fetcher.hSourceInfo.lineNum, 0
	simple.equal 39, fetcher.fetch(), 1
	simple.equal 40, fetcher.fetch(), 2
	simple.equal 41, fetcher.hSourceInfo.lineNum, 2
	simple.equal 42, fetcher.fetch(), 3
	simple.equal 43, fetcher.hSourceInfo.lineNum, 3
	simple.equal 44, fetcher.fetch(), undef
	simple.equal 45, fetcher.hSourceInfo.lineNum, 3
	simple.equal 46, fetcher.fetch(), undef
	simple.equal 47, fetcher.hSourceInfo.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# Test prefix option

(() ->
	fetcher = new Fetcher(undef, ['abc','def','ghi'], {prefix: '>'})
	simple.equal 55, fetcher.fetch(), '>abc'
	simple.equal 56, fetcher.fetch(), '>def'
	)()

# ---------------------------------------------------------------------------
# Test __END__

(() ->

	fetcher = new Fetcher(undef, ['abc','def','__END__','ghi'])
	simple.equal 65, fetcher.fetch(), 'abc'
	simple.equal 66, fetcher.fetch(), 'def'
	simple.equal 67, fetcher.fetch(), undef
	simple.equal 68, fetcher.hSourceInfo.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# Test removing trailing WS

(() ->

	fetcher = new Fetcher(undef, ['abc  ','def  '], {prefix: '>'})
	simple.equal 77, fetcher.fetch(), '>abc'
	simple.equal 78, fetcher.fetch(), '>def'
	)()

# ---------------------------------------------------------------------------
# Test all()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  '], {prefix: '>'})
	lItems = for item from fetcher.all()
		item
	simple.equal 88, lItems, ['>abc','>def']
	)()

# ---------------------------------------------------------------------------
# Test fetchAll()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.equal 96, fetcher.fetchAll(), ['abc','def','ghi']
	)()

# ---------------------------------------------------------------------------
# Test fetchUntil()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.equal 104, fetcher.fetchUntil('def'), ['abc']
	)()

# ---------------------------------------------------------------------------
# Test fetchBlock()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.equal 112, fetcher.fetchBlock(), """
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
	simple.equal 130, fetcher.fetchAll(), ['abc','def','ghi']
	)()

# ---------------------------------------------------------------------------
# Test fetchUntil()

(() ->
	fetcher = new Fetcher(undef, """
			abc
			def
			ghi
			""")
	simple.equal 142, fetcher.fetchUntil('def'), ['abc']
	)()

# ---------------------------------------------------------------------------
# Test fetchBlock()

(() ->
	fetcher = new Fetcher(undef, """
			abc
			def
			ghi
			""")
	simple.equal 154, fetcher.fetchBlock(), """
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
			lAll = fetcher.fetchAll()
			numLines = fetcher.hSourceInfo.lineNum   # set variable numLines
			return arrayToBlock(lAll)

	# ..........................................................

	tester = new MyTester()

	tester.equal 187, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	simple.equal 198, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->
	fetcher = new Fetcher(import.meta.url, """
			abc
			def
			""", {prefix: '---'})

	simple.equal 209, fetcher.fetchBlock(), """
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

	simple.equal 225, fetcher.fetchBlock(), """
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

	while defined(line = fetcher.fetch()) \
			&& (line != '=====')
		pass

	simple.equal 248, line, '====='
	h = fetcher.hSourceInfo
	simple.equal 250, h.altInput.hSourceInfo.filename, 'title.md'
	simple.equal 251, h.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test @hSourceInfo with indentation

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
				#include title.md
			def
			""")

	while defined(line = fetcher.fetch()) \
			&& (line != '\t=====')
		pass

	simple.equal 269, line, '\t====='
	h = fetcher.hSourceInfo
	simple.equal 271, h.altInput.hSourceInfo.filename, 'title.md'
	simple.equal 272, h.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test @sourceInfoStr

(() ->

	fetcher = new Fetcher('test.txt', """
			abc
			#include title.md
			def
			""")
	simple.equal 285, fetcher.sourceInfoStr(), "test.txt/0"

	line = fetcher.fetch()
	simple.equal 288, line, 'abc'
	simple.equal 289, fetcher.sourceInfoStr(), "test.txt/1"

	line = fetcher.fetch()
	simple.equal 292, line, 'title'
	simple.equal 293, fetcher.sourceInfoStr(), "test.txt/2 title.md/1"

	line = fetcher.fetch()
	simple.equal 296, line, '====='
	simple.equal 297, fetcher.sourceInfoStr(), "test.txt/2 title.md/2"

	line = fetcher.fetch()
	simple.equal 300, line, 'def'
	simple.equal 301, fetcher.sourceInfoStr(), "test.txt/3"
	)()
