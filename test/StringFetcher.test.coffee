# StringFetcher.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {
	assert, undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {StringFetcher} from '@jdeighan/mapper'

simple = new UnitTesterNorm()

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
			""", import.meta.url)

	line = input.fetch()
	simple.equal 32, line, 'abc'

	simple.equal 34, input.filename, 'StringFetcher.test.js'
	simple.equal 35, input.lineNum, 1

	line = input.fetch()
	simple.equal 38, line, '\tdef'
	input.unfetch(line)            # make available again

	line = input.fetch()
	simple.equal 42, line, '\tdef'

	line = input.fetch()
	simple.equal 45, line, '\t\tghi'

	line = input.fetch()
	simple.equal 48, line, undef
	)()

# ---------------------------------------------------------------------------

class FetcherTester extends UnitTester

	transformValue: (block) ->

		fetcher = new StringFetcher(block, import.meta.url)
		lLines = []
		while (line = fetcher.fetch())?
			lLines.push line
		return arrayToBlock(lLines)

tester = new FetcherTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 68, """
		abc
		def
		""", """
		abc
		def
		"""

tester.equal 76, """
		abc

		def
		""", """
		abc

		def
		"""

# ---------------------------------------------------------------------------
# --- Test __END__

tester.equal 89, """
		abc
		__END__
		def
		""", """
		abc
		"""

tester.equal 97, """
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

tester.equal 120, """
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

tester.equal 144, """
		first line

			#include file2.txt
		last line
		""", """
		first line

			abc
		last line
		"""
