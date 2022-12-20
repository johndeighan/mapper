# Fetcher.test.coffee

import {
	assert, LOG, LOGVALUE, undef, setDebugging,
	} from '@jdeighan/coffee-utils'
import {toBlock} from '@jdeighan/coffee-utils/block'
import {utest, UnitTester} from '@jdeighan/unit-tester'
import {Fetcher} from '@jdeighan/mapper/fetcher'

stopper = (h) => h.str == 'stop'

# ---------------------------------------------------------------------------
# --- Fetcher should:
#        - handle extension lines
#        - remove trailing whitespace
#        - stop at __END__
#        - handle #include, including setting level correctly
#        - correctly update @lineNum
#        - implement @sourceStr()
#        - handle either spaces or TABs as indentation
#        - allow override of extSep()
#        - implement generators all() and allUntil()
#        - implement getBlock() and getBlockUntil()
# ---------------------------------------------------------------------------

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new Fetcher(hInput)

#			lLines = []
#			for hNode from fetcher.allUntil(stopper)
#				lLines.push hNode.str
#			block = toBlock(lLines)

			block = fetcher.getBlockUntil(stopper)
			return block

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 39, """
		abc

		def
		# --- a comment
		stop
		ghi
		""", """
		abc

		def
		# --- a comment
		"""

	)()

# ---------------------------------------------------------------------------

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new Fetcher(hInput)
			return fetcher.getBlock()

	tester = new MyTester()

	# ------------------------------------------------------------------------

	tester.like 69, """
		abc
		def
		ghi
		""", """
		abc
		def
		ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 81, """
		abc
			def
				ghi
		""", """
		abc
			def
				ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 93, """
		abc
				def
		ghi
		""", """
		abc def
		ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 104, """
		abc
				def
			ghi
		""", """
		abc def
			ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 115, """
		abc
				def
				ghi
		""", """
		abc def ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 125, "abc  \ndef\t\t\nghi", """
		abc
		def
		ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 133, """
		abc
		def
		__END__
		ghi
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

	tester.like 161, {
		source: import.meta.url
		content: """
			abc
			#include include.md
			ghi
			"""}, """
		abc
		header
		======

		ghi
		"""

	tester.like 175, {
		source: import.meta.url
		content: """
			abc
				#include include.md
			ghi
			"""}, """
		abc
			header
			======

		ghi
		"""

	tester.like 189, {
		source: import.meta.url
		content: """
			abc
					#include include.md
			ghi
			"""}, """
		abc #include include.md
		ghi
		"""

	tester.like 200, {
		source: import.meta.url
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

	# ------------------------------------------------------------------------

	)()
