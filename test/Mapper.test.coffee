# Mapper.test.coffee

import {LOG, assert, croak} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn, setDebugging,
	} from '@jdeighan/base-utils/debug'
import {UnitTester, utest} from '@jdeighan/unit-tester'
import {undef, rtrim, replaceVars} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {
	arrayToBlock, blockToArray, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Mapper, FuncMapper, map} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------
# --- Special lines

(() ->
	mapper = new Mapper("""
		line1
		# a comment
		line2

		line3
		""")
	utest.like 27, mapper.get(), {
		str: 'line1'
		level: 0
		lineNum: 1
		}
	utest.like 32, mapper.get(), {
		str: 'line2'
		level: 0
		lineNum: 3
		}
	utest.like 37, mapper.get(), {
		str: 'line3'
		level: 0
		lineNum: 5
		}
	utest.equal 42, mapper.get(), undef

	)()

# ---------------------------------------------------------------------------
# --- Test allUntil()

(() ->

	mapper = new Mapper("""
			abc
			def
			ghi
			jkl
			mno
			""")

	func = (item) -> (item.str == 'jkl')
	lStrings = []

	# --- By default, the end line is discarded
	for item from mapper.allUntil(func)
		lStrings.push item.str

	utest.equal 63, lStrings, ['abc','def','ghi']
	utest.like 67, mapper.fetch(), {str: 'mno'}
	)()

# ---------------------------------------------------------------------------
# --- Test allUntil()

(() ->

	mapper = new Mapper("""
			abc
			def
			ghi
			jkl
			mno
			""")

	func = (item) -> (item.str == 'jkl')
	lStrings = []

	# --- Tell allUntil() to keep the end line
	for item from mapper.allUntil(func, 'keepEndLine')
		lStrings.push item.str

	utest.equal 63, lStrings, ['abc','def','ghi']
	utest.like 91, mapper.fetch(), {str: 'jlk'}
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

	utest.like 110, mapper.fetch(), {str: 'line1'}
	utest.like 111, mapper.fetch(), {str: 'line2'}
	utest.like 112, mapper.fetch(), {str: 'line3'}
	utest.is    113, mapper.fetch(), undef
	)()

# ---------------------------------------------------------------------------
# File title.md contains:
# title
# =====
# ---------------------------------------------------------------------------
# --- Test #include

(() ->

	numLines = undef

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(block)
			block = mapper.getBlock()
			numLines = mapper.lineNum   # set variable numLines
			return block

	# ..........................................................

	myTester = new MyTester()

	myTester.equal 140, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	utest.equal 151, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper("""
			abc
				#include title.md
			def
			""")

	utest.equal 164, mapper.getBlock(), """
			abc
				title
				=====
			def
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test __END__

(() ->

	numLines = undef

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(block)
			block = mapper.getBlock()
			numLines = mapper.lineNum   # set variable numLines
			return block

	# ..........................................................

	myTester = new MyTester()

	myTester.equal 192, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	utest.equal 203, numLines, 2
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

	myTester.equal 223, """
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

	myTester.equal 252, """
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
			""", Mapper)

	utest.equal 281, result, """
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

	utest.equal 310, result, """
			abc
			The meaning of life is 42
			{#for x in lItems}
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test mapNonSpecial

(() ->

	class MyMapper extends Mapper

		isComment: (hNode) -> return hNode.str.match(/// \s* \/ \/ ///)

		mapEmptyLine: (hNode) -> return undef
		mapComment: (hNode) -> return undef
		mapNonSpecial: (hNode) ->
			return hNode.str.length.toString()

	result = map("""
			// test.txt

			abc

			defghi
			""", MyMapper)
	utest.equal 339, result, """
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

		{str, level} = hNode
		return indented(str, level, @oneIndent)

	mapNode: (hNode) ->

		{str, level} = hNode
		return indented("#{str};", level, @oneIndent)

(() ->

	class JSTester extends UnitTester

		transformValue: (block) ->

			return map(block, JSMapper)

	mapTester = new JSTester()

	# --- some utest tests of JSMapper

	mapTester.equal 379, """
			# |||| $:
			y = 2*x
			""", """
			# |||| $:
			y = 2*x;
			"""

	mapTester.equal 387, """
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
				func = (hBlock) -> return (hBlock.level <= level)
				code = @getBlockUntil(func, 'keepEndLine')

				# --- simulate conversion to JavaScript
				code = map(code, JSMapper)

				block = arrayToBlock([
					"# |||| $: {"
					code
					"# |||| }"
					])
			else
				# --- simulate conversion to JavaScript
				code = map(argstr, JSMapper)

				block = arrayToBlock([
					"# |||| $:"
					code
					])
			result = indented(block, level, @oneIndent)
			dbgReturn "mapCmd", result
			return result
		return super(hNode)

(() ->

	class BarTester extends UnitTester

		transformValue: (block) ->

			return map(block, BarMapper)

	mapTester = new BarTester()

	# ..........................................................
	# --- some utest tests of BarMapper

	mapTester.equal 464, """
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

	mapTester.equal 479, """
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

		{str, uobj, level} = hNode
		{comment} = uobj           # isComment() put this here

		if lMatches = comment.match(///^
				\| \| \| \|    # 4 vertical bars
				\s*            # skip whitespace
				(.*)           # anything
				$///)
			str = indented(lMatches[1], level, @oneIndent)
		return str

(() ->

	class DebarTester extends UnitTester

		transformValue: (block) ->

			return map(block, DebarMapper)

	mapTester = new DebarTester()

	# ..........................................................
	# --- some utest tests of DebarMapper

	mapTester.equal 534, """
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

	mapTester.equal 548, """
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
	# --- some utest tests of multiple mapping

	mapTester.equal 583, """
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

	mapTester.equal 598, """
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

# ---------------------------------------------------------------------------
# --- test FuncMapper

(() ->

	# --- Lines that begin with a letter are converted to upper-case
	#     Any other lines are removed

	func = (block) ->
		lResult = []
		for line in blockToArray(block)
			if line.match(/^\s*[A-Za-z]/)
				lResult.push line.toUpperCase()
		return arrayToBlock(lResult)

	# --- test func directly
	block = """
		abc
		---
		xyz
		123
		"""

	utest.equal 642, func(block), """
		ABC
		XYZ
		"""

	# --- test using map()
	mapper = new FuncMapper(import.meta.url, block, func)
	utest.equal 649, map(block, mapper), """
		ABC
		XYZ
		"""

	)()
