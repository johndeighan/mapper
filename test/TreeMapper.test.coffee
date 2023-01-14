# TreeMapper.test.coffee

import {
	undef, pass, OL, defined, toBlock, toArray,
	isEmpty, nonEmpty, isString, isArray, DUMP,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE, dumpLog} from '@jdeighan/base-utils/log'
import {fromTAML} from '@jdeighan/base-utils/taml'
import {
	dbg, dbgEnter, dbgReturn, setDebugging,
	} from '@jdeighan/base-utils/debug'
import {
	UnitTester, utest,
	} from '@jdeighan/unit-tester'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'

import {map} from '@jdeighan/mapper'
import {TreeMapper, getTrace} from '@jdeighan/mapper/tree'
import {markdownify} from '@jdeighan/mapper/markdown'

###
	class TreeMapper should handle the following:
		- remove empty lines and comments
		- extension lines
		- can override @getUserObj()
		- call @walk() to walk the tree
		- can override:
			- beginLevel()
			- visit()
			- endVisit()
			- endLevel()
###

# ---------------------------------------------------------------------------

(() ->
	class MapTester extends UnitTester

		transformValue: (block) ->

			mapper = new TreeMapper(block)
			lNodes = []
			for hNode from mapper.allNodes()
				lNodes.push hNode
			assert isArray(lNodes), "lNodes is #{OL(lNodes)}"
			return lNodes

	mapTester = new MapTester()

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from utest line

	mapTester.like 58, """
			# --- comment, followed by blank line xxx

			abc
			""", [
			{str: 'abc', level: 0},
			]

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from utest line

	mapTester.like 70, """
			# --- comment, followed by blank line

			abc

			# --- this should not be removed

			def
			""", [
			{str: 'abc', level: 0},
			{str: 'def', level: 0},
			]

	# ------------------------------------------------------------------------
	# --- level

	mapTester.like 86, """
			abc
				def
					ghi
				uvw
			xyz
			""", [
			{str: 'abc', level: 0 },
			{str: 'def', level: 1 },
			{str: 'ghi', level: 2 },
			{str: 'uvw', level: 1 },
			{str: 'xyz', level: 0 },
			]
	)()

# ---------------------------------------------------------------------------
# Create a more compact mapTester

(() ->
	class MapTester extends UnitTester

		constructor: () ->

			super()
			@debug = false

		transformValue: (block) ->

			mapper = new TreeMapper(block)
			lNodes = []
			for hNode from mapper.allNodes()
				lNodes.push hNode
			if @debug
				LOG 'lNodes', lNodes
			assert isArray(lNodes), "lNodes is #{OL(lNodes)}"
			return lNodes

		eval_expr: (str) ->

			str = str.replace(/\bundef\b/g, 'undefined')
			return Function('"use strict";return (' + str + ')')();

		getUserObj: (line) ->

			pos = line.indexOf(' ')
			assert (pos > 0), "Missing 1st space char in #{OL(line)}"
			level = parseInt(line.substring(0, pos))
			str = line.substring(pos+1).replace(/\\N/g, '\n').replace(/\\T/g, '\t')

			if (str[0] == '{')
				str = @eval_expr(str)

			return {str, level}

		transformExpected: (block) ->

			lExpected = []
			for line in toArray(block)
				if @debug
					LOG 'transform line', line
				lExpected.push @getUserObj(line)
			if @debug
				LOG 'lExpected', lExpected
			assert isArray(lExpected), "lExpected is #{OL(lExpected)}"
			return lExpected

		doDebug: (flag=true) ->

			@debug = flag
			return

	mapTester = new MapTester()

	# ------------------------------------------------------------------------

	mapTester.like 161, """
			abc
				def
					ghi
			""", """
			0 abc
			1 def
			2 ghi
			"""

	# ------------------------------------------------------------------------
	# --- const replacement

	mapTester.like 174, """
			#define name John Deighan
			abc
			__name__
			""", """
			0 abc
			0 John Deighan
			"""

	# ------------------------------------------------------------------------
	# --- extension lines

	mapTester.like 186, """
			abc
					&& def
					&& ghi
			xyz
			""", """
			0 abc && def && ghi
			0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - block (default)

	mapTester.like 199, """
			func(<<<)
				abc
				def

			xyz
			""", """
			0 func("abc\\ndef")
			0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - block (explicit)

	mapTester.like 213, """
			func(<<<)
				===
				abc
				def

			xyz
			""", """
			0 func("abc\\ndef")
			0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - oneline

	mapTester.like 228, """
			func(<<<)
				...
				abc
				def

			xyz
			""", """
			0 func("abc def")
			0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - oneline

	mapTester.like 243, """
			func(<<<)
				...abc
					def

			xyz
			""", """
			0 func("abc def")
			0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - TAML

	mapTester.like 257, """
			func(<<<)
				---
				- abc
				- def

			xyz
			""", """
			0 func(["abc","def"])
			0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- using __END__

	mapTester.like 272, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# ------------------------------------------------------------------------
	# --- test #ifdef with no value - value not defined

	mapTester.like 287, """
			#ifdef mobile
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with no value - value defined

	mapTester.like 298, """
			#define mobile anything
			#ifdef mobile
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value not defined

	mapTester.like 312, """
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined, but different

	mapTester.like 323, """
			#define mobile apple
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined and same

	mapTester.like 335, """
			#define mobile samsung
			#ifdef mobile samsung
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# ------------------------------------------------------------------------
	# --- test #ifndef with no value - not defined

	mapTester.like 349, """
			#ifndef mobile
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with no value - defined

	mapTester.like 361, """
			#define mobile anything
			#ifndef mobile
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# ------------------------------------------------------------------------
	# --- test #ifndef with a value - not defined

	mapTester.like 374, """
			#ifndef mobile samsung
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with a value - defined, but different

	mapTester.like 386, """
			#define mobile apple
			#ifndef mobile samsung
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with a value - defined and same

	mapTester.like 399, """
			#define mobile samsung
			#ifndef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# ------------------------------------------------------------------------
	# --- nested commands

	mapTester.like 412, """
			#define mobile samsung
			#define large anything
			#ifdef mobile samsung
				#ifdef large
					abc
						def
			""", """
			0 abc
			1 def
			"""

	# --- nested commands

	mapTester.like 426, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifdef large
					abc
			""", ""

	# --- nested commands

	mapTester.like 436, """
			#define mobile samsung
			#define large anything
			#ifdef mobile samsung
				#ifndef large
					abc
			""", ""

	# --- nested commands

	mapTester.like 446, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifndef large
					abc
			""", ""

	# ----------------------------------------------------------
	# --- nested commands - every combination

	mapTester.like 457, """
			#define mobile samsung
			#define large anything
			#ifdef mobile samsung
				abc
				#ifdef large
					def
			ghi
			""", """
			0 abc
			0 def
			0 ghi
			"""

	# --- nested commands - every combination

	mapTester.like 473, """
			#define mobile samsung
			#ifdef mobile samsung
				abc
				#ifdef large
					def
			ghi
			""", """
			0 abc
			0 ghi
			"""

	# --- nested commands - every combination

	mapTester.like 487, """
			#define large anything
			#ifdef mobile samsung
				abc
				#ifdef large
					def
			ghi
			""", """
			0 ghi
			"""

	# --- nested commands - every combination

	mapTester.like 500, """
			#ifdef mobile samsung
				abc
				#ifdef large
					def
			ghi
			""", """
			0 ghi
			"""

	)()

# ---------------------------------------------------------------------------
#             BEGIN walk
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Test TreeMapper.walk()

(() ->
	class Tester extends UnitTester

		transformValue: (block) ->

			return getTrace(block)

	walkTester = new Tester()

	walkTester.equal 528, "",
			"""
			BEGIN WALK
			END WALK
			"""

	walkTester.equal 534, """
			abc
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT 0 'abc'
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 545, """
			abc
			def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT 0 'abc'
			END VISIT 0 'abc'
			VISIT 0 'def'
			END VISIT 0 'def'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 559, """
			abc
				def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT 0 'abc'
				BEGIN LEVEL 1
				VISIT 1 'def'
				END VISIT 1 'def'
				END LEVEL 1
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 575, """
			# this is a unit test
			abc

				def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT 0 'abc'
				BEGIN LEVEL 1
				VISIT 1 'def'
				END VISIT 1 'def'
				END LEVEL 1
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 593, """
			# this is a unit test
			abc
			__END__
				def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT 0 'abc'
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 607, """
			# this is a unit test
			abc
					def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT 0 'abc˳def'
			END VISIT 0 'abc˳def'
			END LEVEL 0
			END WALK
			"""

	)()

# ---------------------------------------------------------------------------
#             END walk
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
#             BEGIN ifdef
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

class WalkTester extends UnitTester

	transformValue: (block) ->

			return getTrace(block)

walkTester = new WalkTester()

# ..........................................................

walkTester.equal 642, """
		abc
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 653, """
		abc
		def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		VISIT 0 'def'
		END VISIT 0 'def'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 667, """
		abc
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
			BEGIN LEVEL 1
			VISIT 1 'def'
			END VISIT 1 'def'
			END LEVEL 1
		END VISIT 0 'abc'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 683, """
		abc
		#ifdef NOPE
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 696, """
		abc
		#ifndef NOPE
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		VISIT 0 'def'
		END VISIT 0 'def'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 711, """
		#define NOPE 42
		abc
		#ifndef NOPE
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 725, """
		#define NOPE 42
		abc
		#ifdef NOPE
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		VISIT 0 'def'
		END VISIT 0 'def'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 741, """
		#define NOPE 42
		#define name John
		abc
		#ifdef NOPE
			def
			#ifdef name
				ghi
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		VISIT 0 'def'
		END VISIT 0 'def'
		VISIT 0 'ghi'
		END VISIT 0 'ghi'
		END LEVEL 0
		END WALK
		"""

# ---------------------------------------------------------------------------
#             END ifdef
# ---------------------------------------------------------------------------

# --- Test TreeMapper.get() with special lines

(() ->
	mapper = new TreeMapper("""
		line1
		# a comment
		line2

		line3
		""")
	utest.like 776, mapper.get(), {
		str: 'line1'
		level: 0
		source: "<unknown>/1"
		}
	utest.like 781, mapper.get(), {
		str: 'line2'
		level: 0
		source: "<unknown>/3"
		}
	utest.like 786, mapper.get(), {
		str: 'line3'
		level: 0
		source: "<unknown>/5"
		}
	utest.equal 791, mapper.get(), undef

	)()

# ---------------------------------------------------------------------------
# Test TreeMapper.get()

(() ->
	mapper = new TreeMapper("""
			# --- a comment

			abc
				def
					ghi
			""")

	utest.like 807, mapper.get(), {
		str:  'abc'
		level: 0
		}
	utest.like 811, mapper.get(), {
		str:  'def'
		level: 1
		}
	utest.like 815, mapper.get(), {
		str:  'ghi'
		level: 2
		}
	utest.equal 819, mapper.get(), undef
	)()

# ---------------------------------------------------------------------------
# Test __END__ and extension lines with TreeMapper.get()

(() ->
	mapper = new TreeMapper("""
			abc
					def
				ghi
			__END__
					ghi
			""")

	# --- get() should return {uobj, level}

	utest.like 836, mapper.get(), {
		str: 'abc def'
		level: 0
		}
	utest.like 840, mapper.get(), {
		str: 'ghi'
		level: 1
		}
	utest.equal 844, mapper.get(), undef
	)()

# ---------------------------------------------------------------------------
# __END__ only works with no identation

(() ->
	utest.fails 851, () -> map("""
			abc
					def
				ghi
				__END__
					ghi
			""", TreeMapper)
	)()

# ---------------------------------------------------------------------------

(() ->

	class Tester extends UnitTester

		transformValue: (block) ->

			return map(block, TreeMapper)

	treeTester = new Tester()

	# ---------------------------------------------------------------------------
	# --- Test basic reading till EOF

	treeTester.equal 875, """
			abc
			def
			""", """
			abc
			def
			"""

	treeTester.equal 883, """
			abc

			def
			""", """
			abc
			def
			"""

	treeTester.equal 892, """
		# --- a comment
		p
			margin: 0
			span
				color: red
		""", """
		p
			margin: 0
			span
				color: red
		"""

	)()

# ---------------------------------------------------------------------------
# Test empty line handling

(() ->
	class MyMapper extends TreeMapper

		# --- This removes blank lines
		mapEmptyLine: () ->

			dbg "in MyMapper.mapEmptyLine()"
			return undef

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, MyMapper)

	treeTester = new MyTester()

	# ..........................................................

	block = """
			abc

			def
			"""

	utest.equal 937, map(block, MyMapper), """
			abc
			def
			"""

	treeTester.equal 942, block, """
			abc
			def
			"""

	)()

# ---------------------------------------------------------------------------
# Test comment handling

(() ->
	class MyMapper extends TreeMapper

		isComment: (hNode) ->

			# --- comments start with //
			return hNode.str.match(///^ \/ \/ ///)

		mapComment: (hNode) ->

			# --- remove comments
			return undef

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, MyMapper)

	treeTester = new MyTester()

	# ..........................................................

	block = """
			// a comment - should be removed
			//also a comment
			# not a comment
			abc
			def
			"""

	utest.equal 985, map(block, MyMapper), """
			# not a comment
			abc
			def
			"""

	treeTester.equal 991, block, """
			# not a comment
			abc
			def
			"""

	)()

# ---------------------------------------------------------------------------
# Test command handling

(() ->
	class MyMapper extends TreeMapper

		isCmd: (hNode) ->
			# --- commands consist of '-' + one whitespace char + word
			if (lMatches = hNode.str.match(///^ - \s (\w+) $///))
				hNode.uobj = {
					cmd: lMatches[1]
					argstr: ''
					}
				return true
			else
				return false

		# .......................................................

		mapCmd: (hNode) ->

			# --- NOTE: this disables handling all commands,
			#           i.e. #define, etc.
			# --- Returning any non-undef value prevents discarding hNode
			#     and sets key uobj to the returned value
			return hNode.uobj

		# .......................................................

		visitCmd: (hNode) ->

			dbgEnter "MyMapper.visitCmd"
			result = "COMMAND: #{hNode.uobj.cmd}"
			dbgReturn "MyMapper.visitCmd", result
			return result

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->
			return map(block, MyMapper)

	treeTester = new MyTester()

	# ..........................................................

	block = """
			# remove this

			abc
			- command
			def
			"""

	treeTester.equal 1054, block, """
			abc
			COMMAND: command
			def
			"""

	)()

# ---------------------------------------------------------------------------
# try retaining indentation for mapped lines

(()->

	# --- NOTE: getUserObj() returns anything,
	#           or undef to ignore the line

	class MyMapper extends TreeMapper

		# --- This maps all non-empty lines to the string 'x'
		#     and removes all empty lines
		getUserObj: (hNode) ->

			dbgEnter "MyMapper.getUserObj", hNode
			{str, level} = hNode
			if isEmpty(str)
				dbgReturn "MyMapper.getUserObj", undef
				return undef
			else
				result = 'x'
				dbgReturn "MyMapper.getUserObj", result
				return result

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, MyMapper)

	treeTester = new MyTester()

	# ..........................................................

	treeTester.equal 1098, """
			abc
				def

			ghi
			""", """
			x
				x
			x
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test ability to access 'this' object from a TreeMapper
#     Goal: remove not only blank lines, but also the line following

(()->

	class MyMapper extends TreeMapper

		# --- Remove blank lines PLUS the line following a blank line
		mapEmptyLine: (hNode) ->

			follow = @fetch()
			return undef    # remove empty lines

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, MyMapper)

	treeTester = new MyTester()

	# ..........................................................

	treeTester.equal 1136, """
			abc

			def
			ghi
			""", """
			abc
			ghi
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test #include

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, TreeMapper)

	# ..........................................................

	treeTester = new MyTester()

	treeTester.equal 1162, """
			abc
				#include title.md
			def
			""", """
			abc
				title
				=====
			def
			"""

	)()

# ---------------------------------------------------------------------------
# --- Test allNodes()

(() ->

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new TreeMapper(block)
			return Array.from(mapper.allNodes())

	treeTester = new MyTester()

	treeTester.like 1191, """
			abc
				def
					ghi
			jkl
			""", fromTAML("""
			---
			-
				level: 0
				str: 'abc'
			-
				level: 1
				str: 'def'
			-
				level: 2
				str: 'ghi'
			-
				level: 0
				str: 'jkl'
			""")

	)()

# ---------------------------------------------------------------------------

(() ->

	mapper = new TreeMapper("""
			if (x == 2)
				doThis
				doThat
					then this
			while (x > 2)
				--x
			""")

	utest.like 1227, mapper.get(),  {level:0, str: 'if (x == 2)'}
	utest.like 1228, mapper.get(),  {level:1, str: 'doThis'}
	utest.like 1229, mapper.get(),  {level:1, str: 'doThat'}
	utest.like 1230, mapper.get(),  {level:2, str: 'then this'}
	utest.like 1231, mapper.get(),  {level:0, str: 'while (x > 2)'}
	utest.like 1232, mapper.get(),  {level:1, str: '--x'}
	)()

# ---------------------------------------------------------------------------
# --- Test HEREDOC

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, TreeMapper)

	# ..........................................................

	treeTester = new MyTester()

	treeTester.equal 1250, """
			abc
			if x == <<<
				abc
				def

			def
			""", """
			abc
			if x == "abc\\ndef"
			def
			"""

	treeTester.equal 1263, """
			abc
			if x == <<<
				===
				abc
				def

			def
			""", """
			abc
			if x == "abc\\ndef"
			def
			"""

	treeTester.equal 1277, """
			abc
			if x == <<<
				...
				abc
				def

			def
			""", """
			abc
			if x == "abc def"
			def
			"""

	)()

# ---------------------------------------------------------------------------
# --- A more complex example

class HtmlMapper extends TreeMapper

	getUserObj: (hNode) ->

		dbgEnter "HtmlMapper.getUserObj", hNode
		{str, level} = hNode
		lMatches = str.match(///^
				(\S+)     # the tag
				(?:
					\s+    # some whitespace
					(.*)   # everything else
					)?     # optional
				$///)
		assert defined(lMatches), "missing HTML tag: #{OL(str)}"
		[_, tag, text] = lMatches
		hResult = {
			tag
			level: @level
			}
		switch tag
			when 'body'
				assert isEmpty(text), "body tag doesn't allow content"
			when 'p', 'div'
				if nonEmpty(text)
					hResult.body = text
			when 'div:markdown'
				hResult.tag = 'div'
				body = @fetchBlockAtLevel(level+1)
				dbg "body", body
				if nonEmpty(body)
					md = markdownify(body)
					dbg "md", md
					hResult.body = md
			else
				croak "Unknown tag: #{OL(tag)}"

		dbgReturn "HtmlMapper.getUserObj", hResult
		return hResult

	# .......................................................

	visit: (hNode, hEnv, hParentEnv) ->

		dbgEnter 'HtmlMapper.visit', hNode
		{str, uobj, level} = hNode
		lParts = [indented("<#{uobj.tag}>", level)]
		if nonEmpty(uobj.body)
			lParts.push indented(uobj.body, level+1)
		result = toBlock(lParts)
		dbgReturn 'HtmlMapper.visit', result
		return result

	# .......................................................

	endVisit: (hNode) ->

		dbgEnter 'HtmlMapper.endVisit', hNode
		{uobj, level} = hNode
		result = indented("</#{uobj.tag}>", level)
		dbgReturn 'HtmlMapper.endVisit', result
		return result

	# .......................................................

	mapComment: (hNode) ->

		dbgEnter 'HtmlMapper.mapComment', hNode

		# --- NOTE: in Mapper.isComment(), the comment text
		#           is placed in hNode._commentText

		{level, _commentText} = hNode
		result = "<!-- #{_commentText} -->"
		dbgReturn 'HtmlMapper.mapComment', result
		return result

# ---------------------------------------------------------------------------

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, HtmlMapper)

	treeTester = new MyTester()

	# ----------------------------------------------------------

	treeTester.equal 1386, """
			body
				# a comment

				div:markdown
					A title
					=======

					some text

				div
					p more text
			""", """
			<body>
				<!-- a comment -->
				<div>
					<h1>A title</h1>
					<p>some text</p>
				</div>
				<div>
					<p>
						more text
					</p>
				</div>
			</body>
			"""

	)()

# ---------------------------------------------------------------------------
# --- test #ifdef and #ifndef

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, TreeMapper)

	treeTester = new MyTester()

	treeTester.equal 1428, """
			abc
			#ifdef something
				def
				ghi
			#ifndef something
				xyz
			""", """
			abc
			xyz
			"""

	)()

# ---------------------------------------------------------------------------
# --- test beginLevel() and endLevel()

(() ->

	lTrace = []

	class MyMapper extends TreeMapper

		beginLevel: (hEnv, hNode) ->
			lTrace.push "B #{hNode.level}"
			return

		endLevel: (hEnv, hNode) ->
			lTrace.push "E #{hNode.level}"
			return

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, MyMapper)

	treeTester = new MyTester()

	treeTester.equal 1467, """
			abc
				def
			""", """
			abc
				def
			"""

	utest.equal 1475, lTrace, [
		"B 0"
		"B 1"
		"E 1"
		"E 0"
		]

	)()

# ---------------------------------------------------------------------------
