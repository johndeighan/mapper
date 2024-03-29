# Fetcher.test.coffee

import {
	undef, defined, spaces, toArray, toBlock,
	} from '@jdeighan/base-utils'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {equal, like, UnitTester} from '@jdeighan/base-utils/utest'

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

	tester.equal """
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

	tester.equal gen(), """
		0 abc
		0 def
		"""

	# ----------------------------------------------------------

	tester.equal ['abc  ', 'def\t\t'], "0 abc\n0 def"

	# ----------------------------------------------------------
	# NOTE: Our output does not take level into account

	tester.equal """
		abc
			def
		ghi
		""", """
		0 abc
		1 def
		0 ghi
		"""

	# ----------------------------------------------------------

	tester.equal """
		abc
				def
		ghi
		""", """
		0 abc def
		0 ghi
		"""

	# ----------------------------------------------------------

	tester.equal """
		abc
		def
		__END__
		ghi
		""", """
		0 abc
		0 def
		"""

	# ----------------------------------------------------------

	tester.equal ["abc", "def"], """
		0 abc
		0 def
		"""

	# ----------------------------------------------------------
	# --- test TABs

	tester.equal ["abc", "\tdef", "\t\tghi"], """
		0 abc
		1 def
		2 ghi
		"""

	# ----------------------------------------------------------
	# --- test spaces

	tester.equal ["abc", spaces(3)+"def", spaces(6)+"ghi"], """
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
	like node1, {
		str: 'abc def ghi'
		source: "<unknown>/1"
		}

	node2 = fetcher.fetch()
	like node2, {
		str: 'jkl'
		source: "<unknown>/4"
		}

	node3 = fetcher.fetch()
	equal node3, undef

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
	like node1, {
		str: 'abc def ghi'
		source: "test.coffee/1"
		}

	node2 = fetcher.fetch()
	like node2, {
		str: 'jkl'
		source: "test.coffee/4"
		}

	node3 = fetcher.fetch()
	equal node3, undef

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
	like node1, {
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

	tester.like """
		abc
		def
		""", [
			{str: 'abc', level: 0}
			{str: 'def', level: 0}
			]

	# ----------------------------------------------------------

	tester.like """
		abc
			def
		ghi
		""", [
			{str: 'abc', level: 0}
			{str: 'def', level: 1}
			{str: 'ghi', level: 0}
			]

	# ----------------------------------------------------------

	tester.like """
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

	tester.equal """
		abc
		def
		""", """
		abc
		def
		"""

	# ----------------------------------------------------------

	tester.equal """
		abc
			def
		ghi
		""", """
		abc
			def
		ghi
		"""

	# ----------------------------------------------------------

	tester.equal """
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

	tester.equal """
		abc
		def
		""", [
		'abc'
		'def'
		]

	# ----------------------------------------------------------

	tester.equal """
		abc
			def
		ghi
		""", [
		'abc'
		'	def'
		'ghi'
		]

	# ----------------------------------------------------------

	tester.equal """
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

	tester.equal """
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

	tester.equal """
		abc
				def
		ghi
		""", """
		ABC DEF
		GHI
		"""

	)()

# ---------------------------------------------------------------------------

(() ->
	# --- test option 'noLevels'

	class MyTester extends UnitTester

		transformValue: (hInput) ->

			fetcher = new Fetcher(hInput, {noLevels: true})
			return fetcher.getBlock()

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal """
		abc
			def
		ghi
		""", """
		abc def
		ghi
		"""

	tester.equal """
		abc
		   def
		ghi
		""", """
		abc def
		ghi
		"""

	)()
