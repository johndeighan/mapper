# Fetcher.test.coffee

import {haltOnError} from '@jdeighan/base-utils'
import {
	assert, LOG, LOGVALUE, undef, setDebugging,
	} from '@jdeighan/coffee-utils'
import {utest, UnitTester} from '@jdeighan/unit-tester'
import {Fetcher} from '@jdeighan/mapper/fetcher'

haltOnError false

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
			return fetcher.getBlock()

	tester = new MyTester()

	# ------------------------------------------------------------------------

	tester.like 38, """
		abc
		def
		ghi
		""", """
		abc
		def
		ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 50, """
		abc
			def
				ghi
		""", """
		abc
			def
				ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 62, """
		abc
				def
		ghi
		""", """
		abc def
		ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 73, """
		abc
				def
			ghi
		""", """
		abc def
			ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 84, """
		abc
				def
				ghi
		""", """
		abc def ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 94, "abc  \ndef\t\t\nghi", """
		abc
		def
		ghi
		"""

	# ------------------------------------------------------------------------

	tester.like 102, """
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

	tester.like 130, {
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

	tester.like 144, {
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

	tester.like 158, {
		source: import.meta.url
		content: """
			abc
					#include include.md
			ghi
			"""}, """
		abc #include include.md
		ghi
		"""

	tester.like 169, {
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
