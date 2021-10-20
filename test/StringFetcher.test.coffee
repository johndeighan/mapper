# StringFetcher.test.coffee

import assert from 'assert'

import {
	undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {hPrivEnv} from '@jdeighan/coffee-utils/privenv'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {StringFetcher} from '@jdeighan/string-input'

dir = mydir(`import.meta.url`)
hPrivEnv.DIR_MARKDOWN = mkpath(dir, 'markdown')
hPrivEnv.DIR_DATA = mkpath(dir, 'data')

simple = new UnitTester()

###
	class StringFetcher should handle the following:
		- #include <file> statements, when DIR_* env vars are set
		- patch {{FILE}} with the name of the input file
		- patch {{LINE}} with the line number
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
	simple.equal 37, line, 'abc'

	hInfo = input.getPositionInfo()
	simple.equal 40, hInfo, {
			file: 'unit test',
			lineNum: 1,
			}

	line = input.fetch()
	simple.equal 46, line, '\tdef'
	input.unfetch(line)            # make available again

	line = input.fetch()
	simple.equal 50, line, '\tdef'

	line = input.fetch()
	simple.equal 53, line, '\t\tghi'

	line = input.fetch()
	simple.equal 56, line, undef
	)()

# ---------------------------------------------------------------------------

class GatherTester extends UnitTester

	transformValue: (oInput) ->

		assert oInput instanceof StringFetcher,
			"oInput should be a StringFetcher object"

		return oInput.fetchAllBlock()

tester = new GatherTester()

# ---------------------------------------------------------------------------
# --- Test basic reading till EOF

tester.equal 75, new StringFetcher("""
		abc
		def
		"""), """
		abc
		def
		"""

tester.equal 83, new StringFetcher("""
		abc

		def
		"""), """
		abc

		def
		"""

# ---------------------------------------------------------------------------
# --- Test __END__

tester.equal 96, new StringFetcher("""
		abc
		__END__
		def
		"""), """
		abc
		"""

tester.equal 104, new StringFetcher("""
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

tester.equal 127, new StringFetcher("""
		first line

			#include file.txt
		last line
		"""), """
		first line

			abc
			def
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

tester.equal 151, new StringFetcher("""
		first line

			#include file2.txt
		last line
		"""), """
		first line

			abc
		last line
		"""

# ---------------------------------------------------------------------------
# --- Test patching file name

tester.equal 166, new StringFetcher("""
		in file {{FILE}}
		ok
		exiting file {{FILE}}
		"""), """
		in file unit test
		ok
		exiting file unit test
		"""


# ---------------------------------------------------------------------------
# --- Test patching line number

tester.equal 180, new StringFetcher("""
		on line {{LINE}}
		ok
		on line {{LINE}}
		"""), """
		on line 1
		ok
		on line 3
		"""
