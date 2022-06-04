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
	simple.equal 36, fetcher.lineNum, 1
	simple.succeeds 37, () -> fetcher.unfetch(1)
	simple.equal 38, fetcher.lineNum, 0
	simple.equal 39, fetcher.fetch(), 1
	simple.equal 40, fetcher.fetch(), 2
	simple.equal 41, fetcher.lineNum, 2
	simple.equal 42, fetcher.fetch(), 3
	simple.equal 43, fetcher.lineNum, 3
	simple.equal 44, fetcher.fetch(), undef
	simple.equal 45, fetcher.lineNum, 3
	simple.equal 46, fetcher.fetch(), undef
	simple.equal 47, fetcher.lineNum, 3
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
	simple.equal 68, fetcher.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# Test removing trailing WS

(() ->

	fetcher = new Fetcher(undef, ['abc  ','def  '], {prefix: '>'})
	simple.equal 76, fetcher.fetch(), '>abc'
	simple.equal 77, fetcher.fetch(), '>def'
	)()

# ---------------------------------------------------------------------------
# Test all()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  '], {prefix: '>'})
	lItems = for item from fetcher.all()
		item
	simple.equal 87, lItems, ['>abc','>def']
	)()

# ---------------------------------------------------------------------------
# Test fetchAll()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.equal 95, fetcher.fetchAll(), ['abc','def','ghi']
	)()

# ---------------------------------------------------------------------------
# Test fetchUntil()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.equal 103, fetcher.fetchUntil('def'), ['abc']
	)()

# ---------------------------------------------------------------------------
# Test fetchBlock()

(() ->
	fetcher = new Fetcher(undef, ['abc  ','def  ','ghi'])
	simple.equal 111, fetcher.fetchBlock(), """
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
	simple.equal 129, fetcher.fetchAll(), ['abc','def','ghi']
	)()

# ---------------------------------------------------------------------------
# Test fetchUntil()

(() ->
	fetcher = new Fetcher(undef, """
			abc
			def
			ghi
			""")
	simple.equal 141, fetcher.fetchUntil('def'), ['abc']
	)()

# ---------------------------------------------------------------------------
# Test fetchBlock()

(() ->
	fetcher = new Fetcher(undef, """
			abc
			def
			ghi
			""")
	simple.equal 153, fetcher.fetchBlock(), """
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
			numLines = fetcher.lineNum   # set variable numLines
			return arrayToBlock(lAll)

	# ..........................................................

	tester = new MyTester()

	tester.equal 186, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	simple.equal 197, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->
	fetcher = new Fetcher(import.meta.url, """
			abc
			def
			""", {prefix: '---'})

	simple.equal 208, fetcher.fetchBlock(), """
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

	simple.equal 224, fetcher.fetchBlock(), """
			abc
				title
				=====
			def
			"""
	)()

# ---------------------------------------------------------------------------
# --- test getSourceInfo()

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
			#include title.md
			def
			""")

	while defined(line = fetcher.fetch()) \
			&& (line != '=====')
		pass

	simple.equal 247, line, '====='
	h = fetcher.getSourceInfo()
	simple.equal 249, h.filename, 'title.md'
	simple.equal 250, h.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- test getSourceInfo() with indentation

(() ->

	fetcher = new Fetcher(import.meta.url, """
			abc
				#include title.md
			def
			""")

	while defined(line = fetcher.fetch()) \
			&& (line != '\t=====')
		pass

	simple.equal 268, line, '\t====='
	h = fetcher.getSourceInfo()
	simple.equal 270, h.filename, 'title.md'
	simple.equal 271, h.lineNum, 2
	)()
