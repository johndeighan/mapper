# Mapper.test.coffee

import {LOG, assert, croak} from '@jdeighan/exceptions'
import {
	dbg, dbgEnter, dbgReturn, setDebugging,
	} from '@jdeighan/exceptions/debug'
import {UnitTester, utest} from '@jdeighan/unit-tester'
import {undef, rtrim, replaceVars} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {
	arrayToBlock, blockToArray, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Mapper, FuncMapper, map} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

(() ->
	mapper = new Mapper(undef, """
		line1
		line2
		line3
		""")

	utest.like 23, mapper.peek(), {str: 'line1', level: 0}
	utest.like 24, mapper.peek(), {str: 'line1', level: 0}
	utest.falsy 25, mapper.eof()
	utest.like 26, token0 = mapper.get(), {str: 'line1'}
	utest.like 27, token1 = mapper.get(), {str: 'line2'}
	utest.equal 28, mapper.lineNum, 2

	utest.falsy 30, mapper.eof()
	utest.succeeds 31, () -> mapper.unfetch(token1)
	utest.succeeds 32, () -> mapper.unfetch(token0)
	utest.like 33, mapper.get(), {str: 'line1'}
	utest.like 34, mapper.get(), {str: 'line2'}
	utest.falsy 35, mapper.eof()

	utest.like 37, token0 = mapper.get(), {str: 'line3'}
	utest.equal 38, mapper.lineNum, 3
	utest.truthy 39, mapper.eof()
	utest.succeeds 40, () -> mapper.unfetch(token0)
	utest.falsy 41, mapper.eof()
	utest.equal 42, mapper.get(), token0
	utest.truthy 43, mapper.eof()
	)()

# ---------------------------------------------------------------------------
# --- Trailing whitespace is stripped from strings

(() ->

	mapper = new Mapper(undef, ['abc', 'def  ', 'ghi\t\t'])

	utest.like 53, mapper.peek(), {str: 'abc'}
	utest.like 54, mapper.peek(), {str: 'abc'}
	utest.falsy 55, mapper.eof()
	utest.like 56, mapper.get(), {str: 'abc'}
	utest.like 57, mapper.get(), {str: 'def'}
	utest.like 58, mapper.get(), {str: 'ghi'}
	utest.equal 59, mapper.lineNum, 3
	)()

# ---------------------------------------------------------------------------
# --- Special lines

(() ->
	mapper = new Mapper(undef, """
		line1
		# a comment
		line2

		line3
		""")
	utest.like 73, mapper.get(), {
		str: 'line1'
		level: 0
		lineNum: 1
		}
	utest.like 78, mapper.get(), {
		str: 'line2'
		level: 0
		lineNum: 3
		}
	utest.like 83, mapper.get(), {
		str: 'line3'
		level: 0
		lineNum: 5
		}
	utest.equal 88, mapper.get(), undef

	)()

# ---------------------------------------------------------------------------
# --- Test fetch(), fetchUntil()

(() ->

	mapper = new Mapper(undef, """
			abc
			def
			ghi
			jkl
			mno
			""")

	utest.like 105, mapper.fetch(), {str: 'abc'}

	# 'jkl' will be discarded
	func = (hNode) -> (hNode.str == 'jkl')
	utest.like 109, mapper.fetchUntil(func, 'discardEndLine'), [
		{str: 'def'}
		{str: 'ghi'}
		]

	utest.like 114, mapper.fetch(), {str: 'mno'}
	utest.equal 115, mapper.lineNum, 5
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
	mapper = new Mapper(undef, generator())

	utest.like 134, mapper.peek(), {str: 'line1'}
	utest.like 135, mapper.peek(), {str: 'line1'}
	utest.falsy 136, mapper.eof()
	utest.like 137, token0 = mapper.get(), {str: 'line1'}
	utest.like 138, token1 = mapper.get(), {str: 'line2'}
	utest.equal 139, mapper.lineNum, 2

	utest.falsy 141, mapper.eof()
	utest.succeeds 142, () -> mapper.unfetch(token1)
	utest.succeeds 143, () -> mapper.unfetch(token0)
	utest.like 144, mapper.get(), {str: 'line1'}
	utest.like 145, mapper.get(), {str: 'line2'}
	utest.falsy 146, mapper.eof()

	utest.like 148, token3 = mapper.get(), {str: 'line3'}
	utest.truthy 149, mapper.eof()
	utest.succeeds 150, () -> mapper.unfetch(token3)
	utest.falsy 151, mapper.eof()
	utest.equal 152, mapper.get(), token3
	utest.truthy 153, mapper.eof()
	utest.equal 154, mapper.lineNum, 3
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

			mapper = new Mapper(import.meta.url, block)
			block = mapper.getBlock()
			numLines = mapper.lineNum   # set variable numLines
			return block

	# ..........................................................

	myTester = new MyTester()

	myTester.equal 181, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	utest.equal 192, numLines, 3
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(import.meta.url, """
			abc
				#include title.md
			def
			""")

	utest.equal 205, mapper.getBlock(), """
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

			mapper = new Mapper(import.meta.url, block)
			block = mapper.getBlock()
			numLines = mapper.lineNum   # set variable numLines
			return block

	# ..........................................................

	myTester = new MyTester()

	myTester.equal 233, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			abc
			def
			"""

	utest.equal 244, numLines, 2
	)()

# ---------------------------------------------------------------------------
# --- Test #include with __END__

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new Mapper(import.meta.url, block)
			block = mapper.getBlock()
			return block

	# ..........................................................

	myTester = new MyTester()

	myTester.equal 264, """
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

			mapper = new Mapper(import.meta.url, block)
			block = mapper.getBlock()
			return block

	# ..........................................................

	myTester = new MyTester()

	myTester.equal 293, """
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

	result = map(import.meta.url, """
			# - test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			""", Mapper)

	utest.equal 322, result, """
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

	result = map(import.meta.url, """
			// test.txt

			abc
			#define meaning 42
			The meaning of life is __meaning__
			#for x in lItems
			""", MyMapper)

	utest.equal 351, result, """
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

	result = map(import.meta.url, """
			// test.txt

			abc

			defghi
			""", MyMapper)
	utest.equal 380, result, """
			3
			6
			"""
	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new Mapper(undef, """
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	utest.like 399, mapper.peek(), {str: 'if (x == 2)', level: 0}
	utest.like 400, mapper.get(),  {str: 'if (x == 2)', level: 0}

	utest.like 402, mapper.peek(), {str: 'doThis', level: 1}
	utest.like 403, mapper.get(),  {str: 'doThis', level: 1}

	utest.like 405, mapper.peek(), {str: 'doThat', level: 1}
	utest.like 406, mapper.get(),  {str: 'doThat', level: 1}

	utest.like 408, mapper.peek(), {str: 'then this', level: 2}
	utest.like 409, mapper.get(),  {str: 'then this', level: 2}

	utest.like 411, mapper.peek(), {str: 'while (x > 2)', level: 0}
	utest.like 412, mapper.get(),  {str: 'while (x > 2)', level: 0}

	utest.like 414, mapper.peek(), {str: '--x', level: 1}
	utest.like 415, mapper.get(),  {str: '--x', level: 1}

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

			return map(import.meta.url, block, JSMapper)

	mapTester = new JSTester()

	# --- some utest tests of JSMapper

	mapTester.equal 453, """
			# |||| $:
			y = 2*x
			""", """
			# |||| $:
			y = 2*x;
			"""

	mapTester.equal 461, """
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
				code = @fetchBlockUntil(func, 'keepEndLine')

				# --- simulate conversion to JavaScript
				code = map(@source, code, JSMapper)

				block = arrayToBlock([
					"# |||| $: {"
					code
					"# |||| }"
					])
			else
				# --- simulate conversion to JavaScript
				code = map(@source, argstr, JSMapper)

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

			return map(import.meta.url, block, BarMapper)

	mapTester = new BarTester()

	# ..........................................................
	# --- some utest tests of BarMapper

	mapTester.equal 538, """
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

	mapTester.equal 553, """
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

			return map(import.meta.url, block, DebarMapper)

	mapTester = new DebarTester()

	# ..........................................................
	# --- some utest tests of DebarMapper

	mapTester.equal 608, """
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

	mapTester.equal 622, """
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

			return map(import.meta.url, block, [BarMapper, DebarMapper])

	mapTester = new MultiTester()

	# ..........................................................
	# --- some utest tests of multiple mapping

	mapTester.equal 657, """
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

	mapTester.equal 672, """
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

	utest.equal 716, func(block), """
		ABC
		XYZ
		"""

	# --- test using map()
	mapper = new FuncMapper(import.meta.url, block, func)
	utest.equal 723, map(import.meta.url, block, mapper), """
		ABC
		XYZ
		"""

	)()
