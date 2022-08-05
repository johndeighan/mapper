# doMap.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, OL, rtrim, replaceVars,
	} from '@jdeighan/coffee-utils'
import {indented} from '@jdeighan/coffee-utils/indent'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {
	arrayToBlock, joinBlocks,
	} from '@jdeighan/coffee-utils/block'

import {Mapper, doMap} from '@jdeighan/mapper'

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

	map: (hNode) ->

		{str, level} = hNode
		return indented("#{str};", level, @oneIndent)

(() ->

	class JSTester extends UnitTester

		transformValue: (block) ->

			return doMap(JSMapper, import.meta.url, block)

	tester = new JSTester()

	# --- some simple tests of JSMapper

	tester.equal 51, """
			# |||| $:
			y = 2*x
			""", """
			# |||| $:
			y = 2*x;
			"""

	tester.equal 59, """
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

		debug "enter mapCmd()", hNode
		{str, uobj, level} = hNode
		{cmd, argstr} = uobj        # isCmd() put this here

		if (cmd == 'reactive')
			if (argstr == '')
				func = (hBlock) -> return (hBlock.level <= level)
				hOptions = {discardEndLine: false}
				code = @fetchBlockUntil(func, hOptions)

				# --- simulate conversion to JavaScript
				code = doMap(JSMapper, @source, code)

				block = arrayToBlock([
					"# |||| $: {"
					code
					"# |||| }"
					])
			else
				# --- simulate conversion to JavaScript
				code = doMap(JSMapper, @source, argstr)

				block = arrayToBlock([
					"# |||| $:"
					code
					])
			result = indented(block, level, @oneIndent)
			debug "return from mapCmd()", result
			return result
		return super(hNode)

(() ->

	class BarTester extends UnitTester

		transformValue: (block) ->

			return doMap(BarMapper, import.meta.url, block)

	tester = new BarTester()

	# ..........................................................
	# --- some simple tests of BarMapper

	tester.equal 137, """
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

	tester.equal 152, """
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

			return doMap(DebarMapper, import.meta.url, block)

	tester = new DebarTester()

	# ..........................................................
	# --- some simple tests of DebarMapper

	tester.equal 207, """
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

	tester.equal 221, """
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

			return doMap([BarMapper, DebarMapper], import.meta.url, block)

	tester = new MultiTester()

	# ..........................................................
	# --- some simple tests of multiple mapping

	tester.equal 256, """
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

	tester.equal 271, """
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
