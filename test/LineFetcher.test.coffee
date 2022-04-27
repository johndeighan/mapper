# LineFetcher.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {
	assert, undef, pass, isEmpty,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {LineFetcher} from '@jdeighan/mapper/fetcher'

simple = new UnitTesterNorm()

###
	class LineFetcher should handle the following:
		- #include <file> statements
		- end file at __END__
###

# ---------------------------------------------------------------------------
# --- test fetch(), unfetch()

(() ->
	input = new LineFetcher("""
			abc
				def
					ghi
			""", import.meta.url)

	line = input.fetch()
	simple.equal 31, line, 'abc'

	simple.equal 33, input.filename, 'LineFetcher.test.js'
	simple.equal 34, input.lineNum, 1

	line = input.fetch()
	simple.equal 37, line, '\tdef'
	input.unfetch(line)            # make available again

	line = input.fetch()
	simple.equal 41, line, '\tdef'

	line = input.fetch()
	simple.equal 44, line, '\t\tghi'

	line = input.fetch()
	simple.equal 47, line, undef
	)()

# ---------------------------------------------------------------------------

class FetcherTester extends UnitTester

	transformValue: (block) ->
		return new LineFetcher(block, import.meta.url).getBlock()

tester = new FetcherTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 62, """
		abc
		def
		""", """
		abc
		def
		"""

tester.equal 70, """
		abc

		def
		""", """
		abc

		def
		"""

# ---------------------------------------------------------------------------
# --- Test __END__

tester.equal 83, """
		abc
		__END__
		def
		""", """
		abc
		"""

# --- Indented __END__ doesn't end the file

tester.equal 93, """
		abc
			def
			__END__
		ghi
		""", """
		abc
			def
			__END__
		ghi
		"""


# ---------------------------------------------------------------------------
# --- Test #include

###
Contents of file test/data/file.txt:

abc
def
###

tester.equal 116, """
		first line

			#include file.txt
		last line
		""", """
		first line

			def
			ghi
		last line
		"""

# ---------------------------------------------------------------------------
# --- Test #include with 2 levels

###
Contents of file test/data/file3.txt:

abc
	def
	#include file.txt
###

tester.equal 140, """
		test this
			#include file3.txt
		last line
		""", """
		test this
			abc
				def
				def
				ghi
		last line
		"""

# ---------------------------------------------------------------------------
# --- Test #include with __END__ in included file

###
	Contents of file test/data/file2.txt:

abc
__END__
def
###

tester.equal 164, """
		first line

			#include file2.txt
		last line
		""", """
		first line

			abc
		last line
		"""
