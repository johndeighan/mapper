# FetcherInc.test.coffee

import {undef, defined} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {UnitTester} from '@jdeighan/base-utils/utest'

import {FetcherInc} from '@jdeighan/mapper/fetcherinc'

# ---------------------------------------------------------------------------
# --- FetcherInc should:
#        - handle #include
#        - override sourceInfoStr() to include include files
# ---------------------------------------------------------------------------

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new FetcherInc(hInput)
			return fetcher.getBlock()

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal """
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

	tester.equal {
		source: 'FetcherInc.test.coffee'
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

	tester.equal {
		source: 'FetcherInc.test.coffee'
		content: """
			abc
					#include include.md
			ghi
			"""}, """
		abc #include include.md
		ghi
		"""

	tester.equal {
		source: 'FetcherInc.test.coffee'
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

			fetcher = new FetcherInc(hInput)
			lNodes = []
			while defined(hNode = fetcher.fetch())
				lNodes.push hNode
			return lNodes

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.like {
		source: 'FetcherInc.test.coffee'
		content: """
			abc
			#include include2.md
			ghi
			"""}, [
			{
				level: 0,
				str: 'abc',
				source: 'FetcherInc.test.coffee/1'}
			{
				level: 0,
				str: 'top',
				source: 'FetcherInc.test.coffee/2 include2.md/1'}
			{
				level: 0,
				str: '===',
				source: 'FetcherInc.test.coffee/2 include2.md/2'}
			{
				level: 1,
				str: 'title',
				source: 'FetcherInc.test.coffee/2 include2.md/3 title.md/1'}
			{
				level: 1,
				str: '=====',
				source: 'FetcherInc.test.coffee/2 include2.md/3 title.md/2'}
			{
				level: 0,
				str: '',
				source: 'FetcherInc.test.coffee/2 include2.md/3 title.md/3'}
			{
				level: 0,
				str: '',
				source: 'FetcherInc.test.coffee/2 include2.md/4'}
			{
				level: 0,
				str: 'ghi',
				source: 'FetcherInc.test.coffee/3'}
			]

	)()
