# Fetcher.test.coffee

import {
	undef, defined, spaces, toArray, toBlock,
	} from '@jdeighan/base-utils'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {utest, UnitTester} from '@jdeighan/unit-tester'

import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------
# --- Fetcher should:
#        ✓ handle any iterable
#        ✓ remove trailing whitespace
#        ✓ handle extension lines
#        ✓ stop at __END__
#        ✓ implement @sourceInfoStr()
#        ✓ handle either spaces or TABs as indentation
#        ✓ implement generator allNodes()
#        ✓ implement getBlock()
#        ✓ allow override of extSep()
#        ✓ allow override of finalizeBlock()
# ---------------------------------------------------------------------------

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new Fetcher(hInput)

			lLines = []
			while defined(hNode = fetcher.fetch())
				lLines.push "#{hNode.level} #{hNode.str}"
			return toBlock(lLines)

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 41, """
		abc
		def
		""", """
		0 abc
		0 def
		"""

	# ----------------------------------------------------------

	gen = () ->
		yield 'abc'
		yield 'def'
		return

	tester.equal 56, gen(), """
		0 abc
		0 def
		"""

	# ----------------------------------------------------------

	tester.equal 63, ['abc  ', 'def\t\t'], "0 abc\n0 def"

	# ----------------------------------------------------------
	# NOTE: Our output does not take level into account

	tester.equal 68, """
		abc
			def
		ghi
		""", """
		0 abc
		1 def
		0 ghi
		"""

	# ----------------------------------------------------------

	tester.equal 80, """
		abc
				def
		ghi
		""", """
		0 abc def
		0 ghi
		"""

	# ----------------------------------------------------------

	tester.equal 91, """
		abc
		def
		__END__
		ghi
		""", """
		0 abc
		0 def
		"""

	# ----------------------------------------------------------

	tester.equal 103, ["abc", "def"], """
		0 abc
		0 def
		"""

	# ----------------------------------------------------------
	# --- test TABs

	tester.equal 111, ["abc", "\tdef", "\t\tghi"], """
		0 abc
		1 def
		2 ghi
		"""

	# ----------------------------------------------------------
	# --- test spaces

	tester.equal 120, ["abc", spaces(3)+"def", spaces(6)+"ghi"], """
		0 abc
		1 def
		2 ghi
		"""

	)()

# ---------------------------------------------------------------------------

(() ->
	fetcher = new Fetcher("""
		abc
				def
				ghi
		jkl
		""")

	node1 = fetcher.fetch()
	utest.like 139, node1, {
		str: 'abc def ghi'
		source: "<unknown>/1"
		}

	node2 = fetcher.fetch()
	utest.like 145, node2, {
		str: 'jkl'
		source: "<unknown>/4"
		}

	node3 = fetcher.fetch()
	utest.equal 151, node3, undef

	)()

# ---------------------------------------------------------------------------

(() ->
	fetcher = new Fetcher({
		source: 'test.coffee',
		content: """
			abc
					def
					ghi
			jkl
			"""})

	node1 = fetcher.fetch()
	utest.like 168, node1, {
		str: 'abc def ghi'
		source: "test.coffee/1"
		}

	node2 = fetcher.fetch()
	utest.like 174, node2, {
		str: 'jkl'
		source: "test.coffee/4"
		}

	node3 = fetcher.fetch()
	utest.equal 180, node3, undef

	)()

# ---------------------------------------------------------------------------

(() ->
	fetcher = new Fetcher({
		source: 'file.coffee'
		content: """
			abc
					def
					ghi
			jkl
			"""
		})

	node1 = fetcher.fetch()
	utest.like 198, node1, {
		str: 'abc def ghi'
		source: "file.coffee/1"
		}
	)()

# ---------------------------------------------------------------------------
# --- test allNodes()

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new Fetcher(hInput)
			return Array.from(fetcher.allNodes())

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.like 219, """
		abc
		def
		""", [
			{str: 'abc', level: 0}
			{str: 'def', level: 0}
			]

	# ----------------------------------------------------------

	tester.like 229, """
		abc
			def
		ghi
		""", [
			{str: 'abc', level: 0}
			{str: 'def', level: 1}
			{str: 'ghi', level: 0}
			]

	# ----------------------------------------------------------

	tester.like 241, """
		abc
				def
		ghi
		""", [
			{str: 'abc def', level: 0}
			{str: 'ghi', level: 0}
			]

	)()

# ---------------------------------------------------------------------------
# --- test getBlock()

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new Fetcher(hInput)
			return fetcher.getBlock()

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 267, """
		abc
		def
		""", """
		abc
		def
		"""

	# ----------------------------------------------------------

	tester.equal 277, """
		abc
			def
		ghi
		""", """
		abc
			def
		ghi
		"""

	# ----------------------------------------------------------

	tester.equal 289, """
		abc
				def
		ghi
		""", """
		abc def
		ghi
		"""

	)()

# ---------------------------------------------------------------------------
# --- test getLines()

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new Fetcher(hInput)
			return fetcher.getLines()

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 315, """
		abc
		def
		""", [
		'abc'
		'def'
		]

	# ----------------------------------------------------------

	tester.equal 325, """
		abc
			def
		ghi
		""", [
		'abc'
		'	def'
		'ghi'
		]

	# ----------------------------------------------------------

	tester.equal 337, """
		abc
				def
		ghi
		""", [
		'abc def'
		'ghi'
		]

	)()

# ---------------------------------------------------------------------------

(() ->
	# --- Don't include a space char when adding extension lines

	class ZhFetcher extends Fetcher

		extSep: (str, nextStr) ->
			return ''

	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new ZhFetcher(hInput)
			return fetcher.getBlock()

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 369, """
		你好
				约翰
		我在这里
		""", """
		你好约翰
		我在这里
		"""

	)()

# ---------------------------------------------------------------------------

(() ->
	# --- capitalize all text returned by getBlock()

	class CapFetcher extends Fetcher

		finalizeBlock: (block) ->
			return block.toUpperCase()

	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new CapFetcher(hInput)
			return fetcher.getBlock()

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal 401, """
		abc
				def
		ghi
		""", """
		ABC DEF
		GHI
		"""

	)()
