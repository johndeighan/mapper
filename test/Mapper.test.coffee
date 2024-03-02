# Mapper.test.coffee

import {
	undef, defined, notdefined, rtrim, toBlock,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn, setDebugging,
	} from '@jdeighan/base-utils/debug'
import {UnitTester, equal, like} from '@jdeighan/base-utils/utest'
import {indented} from '@jdeighan/base-utils/indent'

import {Mapper, map} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------
# --- Special lines

(() ->
	mapper = new Mapper("""
		line1
		# a comment
		line2

		line3
		""")
	like mapper.get(), {
		str: 'line1'
		level: 0
		source: "<unknown>/1"
		}
	like mapper.get(), {
		str: 'line2'
		level: 0
		source: "<unknown>/3"
		}
	like mapper.get(), {
		str: 'line3'
		level: 0
		source: "<unknown>/5"
		}
	equal mapper.get(), undef

	)()

# ---------------------------------------------------------------------------
# --- Test allNodes()

(() ->

	mapper = new Mapper("""
			abc
			def
			ghi
			""")

	lStrings = []

	# --- By default, the end line is kept
	for item from mapper.allNodes()
		lStrings.push item.str

	equal lStrings, ['abc','def','ghi']
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper("""
			abc
			def
			ghi
			""")

	lStrings = []

	for item from mapper.allNodes()
		lStrings.push item.str

	equal lStrings, ['abc','def','ghi']
	)()

# ---------------------------------------------------------------------------

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			mapper = new Mapper(hInput)

			block = mapper.getBlock()
			return block

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal """
		abc

		def
		# --- a comment
		""", """
		abc
		def
		"""

	)()

# ---------------------------------------------------------------------------
# --- to prevent mapping, you must use fetch()

(() ->
	class MyTester extends UnitTester

		transformValue: (hInput) ->

			mapper = new Mapper(hInput)
			lLines = []
			while defined(hNode = mapper.fetch())
				if (hNode.str == 'stop')
					break
				lLines.push hNode.str

			return toBlock(lLines)

	tester = new MyTester()

	# ----------------------------------------------------------

	tester.equal """
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

	# --- A generator is a function that, when you call it,
	#     it returns an iterator

	generator = () ->
		yield 'line1'
		yield 'line2'
		yield 'line3'
		return

	# --- You can pass any iterator to the Mapper() constructor
	mapper = new Mapper(generator())

	like  mapper.fetch(), {str: 'line1'}
	like  mapper.fetch(), {str: 'line2'}
	like  mapper.fetch(), {str: 'line3'}
	equal mapper.fetch(), undef
	)()

# ---------------------------------------------------------------------------
# File title.md contains:
# title
# =====
# ---------------------------------------------------------------------------
# --- Test #include

(() ->
	contents = """
		abc
			#include title.md
		def
		"""

	mapper = new Mapper(contents)
	block = mapper.getBlock()

	equal block, """
		abc
			title
			=====
		def
		"""

	equal mapper.lineNum, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper("""
			abc
				#include title.md
			def
			""")

	equal mapper.getBlock(), """
			abc
				title
				=====
			def
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test __END__

(() =>
	contents = """
			abc
			def
			__END__
			ghi
			jkl
			"""

	mapper = new Mapper(contents)
	block = mapper.getBlock()

	equal block, """
		abc
		def
		"""

	equal mapper.lineNum, 2
	)()

# ---------------------------------------------------------------------------
# --- Test #include with __END__

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(block)
			block = mapper.getBlock()
			return block

	# ..........................................................

	myTester = new MyTester()

	myTester.equal """
			abc
				#include ended.md
			def
			""", """
			abc
				ghi
			def
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test #define

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(block)
			block = mapper.getBlock()
			return block

	# ..........................................................

	myTester = new MyTester()

	myTester.equal """
			abc
			#define meaning 42
			meaning is __meaning__
			""", """
			abc
			meaning is 42
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test map()

(() ->

	# --- Usually:
	#        1. empty lines are removed
	#        2. '#' style comments are recognized and removed
	#        3. Only the #define command is interpreted

	result = map("""
			# - test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			""")

	equal result, """
			abc
			The meaning of life is 42
			"""

	# --- Now, create a subclass that:
	#        1. recognizes '//' style comments and removes them
	#        2. implements a '#for <args>' cmd that outputs '{#for <args>}'

	class MyMapper extends Mapper

		isComment: (hNode) -> return hNode.str.match(///^ \s* \/ \/ ///)

		mapCmd: (hNode) ->
			{cmd, argstr} = hNode.uobj
			if (cmd == 'for')
				return indented("{#for #{argstr}}", hNode.level, @oneIndent)
			else
				return super(hNode)

	result = map("""
			// test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			#for x in lItems
			""", MyMapper)

	equal result, """
			abc
			The meaning of life is 42
			{#for x in lItems}
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test mapToUserObj

(() ->

	class MyMapper extends Mapper

		# --- change definition of a comment
		isComment: (hNode) -> return hNode.str.match(///
				\s*
				\/
				\/
				///)

		mapEmptyLine: (hNode) -> return undef
		mapComment: (hNode) -> return undef
		mapToUserObj: (hNode) ->
			return hNode.str.length.toString()

	result = map("""
			// test.txt

			abc

			defghi
			""", MyMapper)
	equal result, """
			3
			6
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test complex mapping,
#     where source is passed through multiple mappers

# ---------------------------------------------------------------------------
# JSMapper:
#    1. retains comments
#    2. removes empty lines
#    3. appends a semicolon to each non-comment line

class JSMapper extends Mapper

	mapComment: (hNode) ->

		return hNode.str

	mapToUserObj: (hNode) ->
		return hNode.str + ';'

(() ->

	class JSTester extends UnitTester

		transformValue: (block) ->

			return map(block, JSMapper)

	mapTester = new JSTester()

	# --- some tests of JSMapper

	mapTester.equal """
			# |||| $:
			y = 2*x
			""", """
			# |||| $:
			y = 2*x;
			"""

	mapTester.equal """
			# |||| $: {
			y = 2*x
			console.log "OK"
			# |||| }
			""", """
			# |||| $: {
			y = 2*x;
			console.log "OK";
			# |||| }
			"""

	)()

# ---------------------------------------------------------------------------
# BarMapper should:
#    1. Remove comments and empty lines   (happens by default)
#    2. Convert
#          #reactive <code>
#       to
#          # |||| $:
#          <code>
#    3. Convert
#          #reactive
#             <code>
#       to
#          # |||| $: {
#          <code>
#          # |||| }

export class BarMapper extends Mapper

	mapCmd: (hNode) ->

		dbgEnter "mapCmd", hNode
		{str, uobj, level} = hNode
		{cmd, argstr} = uobj        # isCmd() put this here

		if (cmd == 'reactive')
			if (argstr == '')
				# --- A reactive block
				lLines = @fetchLinesAtLevel(level+1)

				# --- simulate conversion to JavaScript
				code = map(lLines, JSMapper)

				block = toBlock([
					"# |||| $: {"
					code
					"# |||| }"
					])
			else
				# --- A reactive statement
				code = map(argstr, JSMapper)

				block = toBlock([
					"# |||| $:"
					code
					])
			dbgReturn "mapCmd", block
			return block

		return super(hNode)

(() ->

	class BarTester extends UnitTester

		transformValue: (block) ->

			return map(block, BarMapper)

	mapTester = new BarTester()

	# ..........................................................
	# --- some tests of BarMapper

	mapTester.equal """
			# --- a comment (should remove)

			<h1>title</h1>
			<script>
				#reactive y = 2*x
			</script>
			""", """
			<h1>title</h1>
			<script>
				# |||| $:
				y = 2*x;
			</script>
			"""

	mapTester.equal """
			# --- a comment (should remove)

			<h1>title</h1>
			<script>
				#reactive
					y = 2*x
					console.log "OK"
			</script>
			""", """
			<h1>title</h1>
			<script>
				# |||| $: {
				y = 2*x;
				console.log "OK";
				# |||| }
			</script>
			"""

	)()

# ---------------------------------------------------------------------------
# DebarMapper should convert:
#     # |||| <something>
# to
#     <something>

export class DebarMapper extends Mapper

	mapComment: (hNode) ->

		{str, uobj, level, _commentText} = hNode

		if lMatches = _commentText.match(///^
				\| \| \| \|    # 4 vertical bars
				\s*            # skip whitespace
				(.*)           # anything
				$///)
			str = lMatches[1]
		return str

(() ->

	class DebarTester extends UnitTester

		transformValue: (block) ->

			return map(block, DebarMapper)

	mapTester = new DebarTester()

	# ..........................................................
	# --- some tests of DebarMapper

	mapTester.equal """
			<h1>title</h1>
			<script>
				# |||| $:
				y = 2*x
			</script>
			""", """
			<h1>title</h1>
			<script>
				$:
				y = 2*x
			</script>
			"""

	mapTester.equal """
			<h1>title</h1>
			<script>
				# |||| $: {
				y = 2*x
				console.log "OK"
				# |||| }
			</script>
			""", """
			<h1>title</h1>
			<script>
				$: {
				y = 2*x
				console.log "OK"
				}
			</script>
			"""

	)()

# ---------------------------------------------------------------------------

(() ->

	class MultiTester extends UnitTester

		transformValue: (block) ->

			return map(block, [BarMapper, DebarMapper])

	mapTester = new MultiTester()

	# ..........................................................
	# --- some tests of multiple mapping

	mapTester.equal """
			# --- a comment (should remove)

			<h1>title</h1>
			<script>
				#reactive y = 2*x
			</script>
			""", """
			<h1>title</h1>
			<script>
				$:
				y = 2*x;
			</script>
			"""

	mapTester.equal """
			# --- a comment (should remove)

			<h1>title</h1>
			<script>
				#reactive
					y = 2*x
					console.log "OK"
			</script>
			""", """
			<h1>title</h1>
			<script>
				$: {
				y = 2*x;
				console.log "OK";
				}
			</script>
			"""

	)()
