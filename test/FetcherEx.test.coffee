# FetcherEx.test.coffee

import {assert, croak} from '@jdeighan/base-utils'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {utest, UnitTester} from '@jdeighan/unit-tester'
import {undef, defined} from '@jdeighan/coffee-utils'
import {FetcherEx} from '@jdeighan/mapper/fetcherex'

# ---------------------------------------------------------------------------
# --- FetcherEx should:
#        - handle #include
#        - override sourceInfoStr() to include include files
# ---------------------------------------------------------------------------

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new FetcherEx(hInput)
			return fetcher.getBlock()

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 28, """
		abc
		def
		""", """
		abc
		def
		"""

	# ------------------------------------------------------------------------
	# --- Test using #include

	# ------------------------------------------------------------------------
	# File include.md (in /test) contains:
	# header
	# ======
	# ------------------------------------------------------------------------
	# File include2.md (in /test) contains:
	# top
	# ===
	#    #include title.md
	# ------------------------------------------------------------------------
	# File title.md (in /test/markdown) contains:
	# title
	# =====
	# ------------------------------------------------------------------------

	tester.equal 54, {
		source: 'FetcherEx.test.coffee'
		content: """
			abc
			#include include.md
			ghi
			"""
		}, """
		abc
		header
		======

		ghi
		"""

	tester.like 69, {
		source: 'FetcherEx.test.coffee'
		content: """
			abc
					#include include.md
			ghi
			"""}, """
		abc #include include.md
		ghi
		"""

	tester.like 80, {
		source: 'FetcherEx.test.coffee'
		content: """
			abc
			#include include2.md
			ghi
			"""}, """
		abc
		top
		===
			title
			=====


		ghi
		"""

	)()

# ---------------------------------------------------------------------------

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new FetcherEx(hInput)
			lNodes = []
			while defined(hNode = fetcher.fetch())
				lNodes.push hNode
			return lNodes

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.like 120, {
		source: 'FetcherEx.test.coffee'
		content: """
			abc
			#include include2.md
			ghi
			"""}, [
			{
				level: 0,
				str: 'abc',
				source: 'FetcherEx.test.coffee/1'}
			{
				level: 0,
				str: 'top',
				source: 'FetcherEx.test.coffee/2 include2.md/1'}
			{
				level: 0,
				str: '===',
				source: 'FetcherEx.test.coffee/2 include2.md/2'}
			{
				level: 1,
				str: 'title',
				source: 'FetcherEx.test.coffee/2 include2.md/3 title.md/1'}
			{
				level: 1,
				str: '=====',
				source: 'FetcherEx.test.coffee/2 include2.md/3 title.md/2'}
			{
				level: 0,
				str: '',
				source: 'FetcherEx.test.coffee/2 include2.md/3 title.md/3'}
			{
				level: 0,
				str: '',
				source: 'FetcherEx.test.coffee/2 include2.md/4'}
			{
				level: 0,
				str: 'ghi',
				source: 'FetcherEx.test.coffee/3'}
			]

	)()