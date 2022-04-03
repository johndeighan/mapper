# StringFetcher.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {
	assert, undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {StringFetcher} from '@jdeighan/mapper'

simple = new UnitTester()

###
	class StringFetcher should handle the following:
		- #include <file> statements
		- replace __LINE, __DIR, __FILE
		- end file at __END__
###

# ---------------------------------------------------------------------------
# --- test fetch(), unfetch()

(() ->
	input = new StringFetcher("""
			abc
				def
					ghi
			""")

	line = input.fetch()
	simple.equal 30, line, 'abc'

	simple.equal 32, input.filename, 'unit test'
	simple.equal 33, input.lineNum, 1

	line = input.fetch()
	simple.equal 36, line, '\tdef'
	input.unfetch(line)            # make available again

	line = input.fetch()
	simple.equal 40, line, '\tdef'

	line = input.fetch()
	simple.equal 43, line, '\t\tghi'

	line = input.fetch()
	simple.equal 46, line, undef
	)()

# ---------------------------------------------------------------------------

class FetcherTester extends UnitTesterNoNorm

	transformValue: (block) ->

		fetcher = new StringFetcher(block)
		lLines = []
		while (line = fetcher.fetch())?
			lLines.push line
		return arrayToBlock(lLines)

tester = new FetcherTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 65, """
		abc
		def
		""", """
		abc
		def
		"""

tester.equal 73, """
		abc

		def
		""", """
		abc

		def
		"""

# ---------------------------------------------------------------------------
# --- Test __END__

tester.equal 86, """
		abc
		__END__
		def
		""", """
		abc
		"""

tester.equal 94, """
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

tester.equal 117, """
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
# --- Test #include with __END__ in included file

###
	Contents of file test/data/file2.txt:

abc
__END__
def
###

tester.equal 141, """
		first line

			#include file2.txt
		last line
		""", """
		first line

			abc
		last line
		"""
