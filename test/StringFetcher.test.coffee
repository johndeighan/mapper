# StringFetcher.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {
	assert, undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {StringFetcher} from '@jdeighan/string-input'

simple = new UnitTester()

###
	class StringFetcher should handle the following:
		- #include <file> statements
		- end file at __END__
###

# ---------------------------------------------------------------------------
# --- test fetch(), unfetch(), getPositionInfo()

(() ->
	input = new StringFetcher("""
			abc
				def
					ghi
			""")

	line = input.fetch()
	simple.equal 33, line, 'abc'

	hInfo = input.getPositionInfo()
	simple.equal 36, hInfo, {
			file: 'unit test',
			lineNum: 1,
			}

	line = input.fetch()
	simple.equal 42, line, '\tdef'
	input.unfetch(line)            # make available again

	line = input.fetch()
	simple.equal 46, line, '\tdef'

	line = input.fetch()
	simple.equal 49, line, '\t\tghi'

	line = input.fetch()
	simple.equal 52, line, undef
	)()

# ---------------------------------------------------------------------------

class GatherTester extends UnitTesterNoNorm

	transformValue: (oInput) ->

		assert oInput instanceof StringFetcher,
			"oInput should be a StringFetcher object"

		return oInput.fetchAllBlock()

tester = new GatherTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 71, new StringFetcher("""
		abc
		def
		"""), """
		abc
		def
		"""

tester.equal 79, new StringFetcher("""
		abc

		def
		"""), """
		abc

		def
		"""

# ---------------------------------------------------------------------------
# --- Test __END__

tester.equal 92, new StringFetcher("""
		abc
		__END__
		def
		"""), """
		abc
		"""

tester.equal 100, new StringFetcher("""
		abc
			def
			__END__
		ghi
		"""), """
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

tester.equal 123, new StringFetcher("""
		first line

			#include file.txt
		last line
		"""), """
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

tester.equal 147, new StringFetcher("""
		first line

			#include file2.txt
		last line
		"""), """
		first line

			abc
		last line
		"""
