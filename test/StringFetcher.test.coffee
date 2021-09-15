# StringFetcher.test.coffee

import {strict as assert} from 'assert'

import {
	undef, pass, isEmpty, isComment,
	} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {StringFetcher} from '@jdeighan/string-input'

dir = mydir(`import.meta.url`)
process.env.DIR_MARKDOWN = mkpath(dir, 'markdown')
process.env.DIR_DATA = mkpath(dir, 'data')

simple = new UnitTester()

###
	class StringFetcher should handle the following:
		- #include <file> statements, when DIR_* env vars are set
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
	simple.equal 35, line, 'abc'

	hInfo = input.getPositionInfo()
	simple.equal 38, hInfo, {
			file: 'unit test',
			lineNum: 1,
			}

	line = input.fetch()
	simple.equal 44, line, '\tdef'
	input.unfetch(line)            # make available again

	line = input.fetch()
	simple.equal 48, line, '\tdef'

	line = input.fetch()
	simple.equal 51, line, '\t\tghi'

	line = input.fetch()
	simple.equal 54, line, undef
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

tester.equal 73, new StringFetcher("""
		abc
		def
		"""), """
		abc
		def
		"""

tester.equal 81, new StringFetcher("""
		abc

		def
		"""), """
		abc

		def
		"""

# ---------------------------------------------------------------------------
# --- Test #include

###
	Contents of file test/data/file.txt:

	abc
	def
###

tester.equal 101, new StringFetcher("""
		first line

			#include file.txt
		last line
		"""), """
		first line

			abc
			def
		last line
		"""