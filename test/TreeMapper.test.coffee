# TreeMapper.test.coffee

import {
	LOG, LOGVALUE, assert, croak, setDebugging, fromTAML,
	} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {UnitTester, UnitTesterNorm, utest} from '@jdeighan/unit-tester'
import {
	undef, pass, OL, defined,
	isEmpty, nonEmpty, isString, isArray,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {arrayToBlock, blockToArray} from '@jdeighan/coffee-utils/block'

import {map} from '@jdeighan/mapper'
import {TreeMapper, trace} from '@jdeighan/mapper/tree'
import {SimpleMarkDownMapper} from '@jdeighan/mapper/markdown'

###
	class TreeMapper should handle the following:
		- remove empty lines and comments
		- extension lines
		- can override @mapNode()
		- call @walk() to walk the tree
		- can override beginLevel(), visit(), endVisit(), endLevel()
###

# ---------------------------------------------------------------------------

(() ->
	class MapTester extends UnitTester

		transformValue: (block) ->

			mapper = new TreeMapper(block)
			lNodes = []
			for hNode from mapper.all()
				lNodes.push hNode
			assert isArray(lNodes), "lNodes is #{OL(lNodes)}"
			return lNodes

	mapTester = new MapTester()

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from utest line

	mapTester.like 53, """
			# --- comment, followed by blank line xxx

			abc
			""", [
			{str: 'abc', level: 0},
			]

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from utest line

	mapTester.like 65, """
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

	mapTester.like 81, """
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
			for hNode from mapper.all()
				lNodes.push hNode
			if @debug
				LOG 'lNodes', lNodes
			assert isArray(lNodes), "lNodes is #{OL(lNodes)}"
			return lNodes

		getUserObj: (line) ->

			pos = line.indexOf(' ')
			assert (pos > 0), "Missing 1st space char in #{OL(line)}"
			level = parseInt(line.substring(0, pos))
			str = line.substring(pos+1).replace(/\\N/g, '\n').replace(/\\T/g, '\t')

			if (str[0] == '{')
				str = eval_expr(str)

			return {str, level}

		transformExpected: (block) ->

			lExpected = []
			for line in blockToArray(block)
				if @debug
					LOG 'line', line
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

	mapTester.like 151, """
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

	mapTester.like 164, """
			#define name John Deighan
			abc
			__name__
			""", """
			0 abc
			0 John Deighan
			"""

	# ------------------------------------------------------------------------
	# --- extension lines

	mapTester.like 176, """
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

	mapTester.like 189, """
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

	mapTester.like 203, """
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

	mapTester.like 218, """
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

	mapTester.like 233, """
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

	mapTester.like 247, """
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
	# --- HEREDOC handling - function

	mapTester.like 262, """
			handleClick(<<<)
				(event) ->
					event.preventDefault()
					alert 'clicked'
					return

			xyz
			""", """
			0 handleClick((event) ->\\N\\Tevent.preventDefault()\\N\\Talert 'clicked'\\N\\Treturn)
			0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- using __END__

	mapTester.like 278, """
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

	mapTester.like 293, """
			#ifdef mobile
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with no value - value defined

	mapTester.like 304, """
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

	mapTester.like 318, """
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined, but different

	mapTester.like 329, """
			#define mobile apple
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined and same

	mapTester.like 341, """
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

	mapTester.like 355, """
			#ifndef mobile
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with no value - defined

	mapTester.like 367, """
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

	mapTester.like 380, """
			#ifndef mobile samsung
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with a value - defined, but different

	mapTester.like 392, """
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

	mapTester.like 405, """
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

	mapTester.like 418, """
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

	mapTester.like 432, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifdef large
					abc
			""", """
			"""

	# --- nested commands

	mapTester.like 443, """
			#define mobile samsung
			#define large anything
			#ifdef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# --- nested commands

	mapTester.like 454, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# ----------------------------------------------------------
	# --- nested commands - every combination

	mapTester.like 466, """
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

	mapTester.like 482, """
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

	mapTester.like 496, """
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

	mapTester.like 509, """
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
	class Tester extends UnitTesterNorm

		transformValue: (block) ->

			return trace(block)

	walkTester = new Tester()

	walkTester.equal 537, """
			""", """
			BEGIN WALK
			END WALK
			"""

	walkTester.equal 543, """
			abc
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc'
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 554, """
			abc
			def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc'
			END VISIT 0 'abc'
			VISIT     0 'def'
			END VISIT 0 'def'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 568, """
			abc
				def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc'
			BEGIN LEVEL 1
			VISIT     1 'def'
			END VISIT 1 'def'
			END LEVEL 1
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 584, """
			# this is a unit test
			abc

				def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc'
			BEGIN LEVEL 1
			VISIT     1 'def'
			END VISIT 1 'def'
			END LEVEL 1
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 602, """
			# this is a unit test
			abc
			__END__
				def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc'
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	walkTester.equal 616, """
			# this is a unit test
			abc
					def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc˳def'
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

class WalkTester extends UnitTesterNorm

	transformValue: (block) ->

			return trace(block)

walkTester = new WalkTester()

# ..........................................................

walkTester.equal 651, """
		abc
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT       0 'abc'
		END VISIT   0 'abc'
		END LEVEL   0
		END WALK
		"""

walkTester.equal 662, """
		abc
		def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT     0 'abc'
		END VISIT 0 'abc'
		VISIT     0 'def'
		END VISIT 0 'def'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 676, """
		abc
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT     0 'abc'
		BEGIN LEVEL 1
		VISIT     1 'def'
		END VISIT 1 'def'
		END LEVEL 1
		END VISIT 0 'abc'
		END LEVEL 0
		END WALK
		"""

walkTester.equal 692, """
		abc
		#ifdef NOPE
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT     0 'abc'
		END VISIT 0 'abc'
		END LEVEL   0
		END WALK
		"""

walkTester.equal 705, """
		abc
		#ifndef NOPE
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT     0 'abc'
		END VISIT 0 'abc'
		VISIT     0 'def'
		END VISIT 0 'def'
		END LEVEL   0
		END WALK
		"""

walkTester.equal 720, """
		#define NOPE 42
		abc
		#ifndef NOPE
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT     0 'abc'
		END VISIT 0 'abc'
		END LEVEL   0
		END WALK
		"""

walkTester.equal 734, """
		#define NOPE 42
		abc
		#ifdef NOPE
			def
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT     0 'abc'
		END VISIT 0 'abc'
		VISIT     0 'def'
		END VISIT 0 'def'
		END LEVEL   0
		END WALK
		"""

walkTester.equal 750, """
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
		VISIT     0 'abc'
		END VISIT 0 'abc'
		VISIT     0 'def'
		END VISIT 0 'def'
		VISIT     0 'ghi'
		END VISIT 0 'ghi'
		END LEVEL   0
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
	utest.like 785, mapper.get(), {
		str: 'line1'
		level: 0
		lineNum: 1
		}
	utest.like 790, mapper.get(), {
		str: 'line2'
		level: 0
		lineNum: 3
		}
	utest.like 795, mapper.get(), {
		str: 'line3'
		level: 0
		lineNum: 5
		}
	utest.equal 800, mapper.get(), undef

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

	utest.like 816, mapper.get(), {
		str:  'abc'
		level: 0
		}
	utest.like 820, mapper.get(), {
		str:  'def'
		level: 1
		}
	utest.like 824, mapper.get(), {
		str:  'ghi'
		level: 2
		}
	utest.equal 828, mapper.get(), undef
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

	utest.like 845, mapper.get(), {
		str: 'abc def'
		level: 0
		}
	utest.like 849, mapper.get(), {
		str: 'ghi'
		level: 1
		}
	utest.equal 853, mapper.get(), undef
	)()

# ---------------------------------------------------------------------------
# __END__ only works with no identation

(() ->
	utest.fails 860, () -> map("""
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

	treeTester.equal 884, """
			abc
			def
			""", """
			abc
			def
			"""

	treeTester.equal 892, """
			abc

			def
			""", """
			abc
			def
			"""

	treeTester.equal 901, """
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

	utest.equal 946, map(block, MyMapper), """
			abc
			def
			"""

	treeTester.equal 951, block, """
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

	utest.equal 994, map(block, MyMapper), """
			# not a comment
			abc
			def
			"""

	treeTester.equal 1000, block, """
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

	treeTester.equal 1063, block, """
			abc
			COMMAND: command
			def
			"""

	)()

# ---------------------------------------------------------------------------
# try retaining indentation for mapped lines

(()->

	# --- NOTE: mapNode() returns anything,
	#           or undef to ignore the line

	class MyMapper extends TreeMapper

		# --- This maps all non-empty lines to the string 'x'
		#     and removes all empty lines
		mapNode: (hNode) ->

			dbgEnter "mapNode", hNode
			{str, level} = hNode
			if isEmpty(str)
				dbgReturn "mapNode", undef
				return undef
			else
				result = 'x'
				dbgReturn "mapNode", result
				return result

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, MyMapper)

	treeTester = new MyTester()

	# ..........................................................

	treeTester.equal 1107, """
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

	treeTester.equal 1145, """
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

	treeTester.equal 1171, """
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
# --- Test getAll()

(() ->

	# ..........................................................

	class MyTester extends UnitTester

		transformValue: (block) ->

			mapper = new TreeMapper(block)
			return Array.from(mapper.all())

	treeTester = new MyTester()

	treeTester.like 1200, """
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

	utest.like 1236, mapper.get(),  {level:0, str: 'if (x == 2)'}
	utest.like 1237, mapper.get(),  {level:1, str: 'doThis'}
	utest.like 1238, mapper.get(),  {level:1, str: 'doThat'}
	utest.like 1239, mapper.get(),  {level:2, str: 'then this'}
	utest.like 1240, mapper.get(),  {level:0, str: 'while (x > 2)'}
	utest.like 1241, mapper.get(),  {level:1, str: '--x'}
	)()

# ---------------------------------------------------------------------------
# --- Test HEREDOC

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, TreeMapper)

	# ..........................................................

	treeTester = new MyTester()

	treeTester.equal 1259, """
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

	treeTester.equal 1272, """
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

	treeTester.equal 1286, """
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

	mapNode: (hNode) ->

		dbgEnter "MyMapper.mapNode", hNode
		{str, level} = hNode
		lMatches = str.match(///^
				(\S+)     # the tag
				(?:
					\s+    # some whitespace
					(.*)   # everything else
					)?     # optional
				$///)
		assert defined(lMatches), "missing HTML tag"
		[_, tag, text] = lMatches
		hResult = {tag, @level}
		switch tag
			when 'body'
				assert isEmpty(text), "body tag doesn't allow content"
			when 'p', 'div'
				if nonEmpty(text)
					hResult.body = text
			when 'div:markdown'
				hResult.tag = 'div'
				body = @fetchBlockAtLevel(level)
				dbg "body", body
				if nonEmpty(body)
					md = map(body, SimpleMarkDownMapper)
					dbg "md", md
					hResult.body = md
			else
				croak "Unknown tag: #{OL(tag)}"

		dbgReturn "MyMapper.mapNode", hResult
		return hResult

	# .......................................................

	visit: (hNode, hUser, lStack) ->

		dbgEnter 'visit', hNode, hUser, lStack
		{str, uobj, level, type} = hNode
		switch type
			when 'comment'
				if lMatches = str.match(///^
						\#
						(.*)
						$///)
					[_, str] = lMatches
					return indented("<!-- #{str.trim()} -->", level)
				else
					return undef
		lParts = [indented("<#{uobj.tag}>", level)]
		if nonEmpty(uobj.body)
			lParts.push indented(uobj.body, level+1)
		result = arrayToBlock(lParts)
		dbgReturn 'visit', result
		return result

	# .......................................................

	endVisit: (hNode, hUser, lStack) ->

		{uobj, level, type} = hNode
		if (type == 'comment')
			return undef

		return indented("</#{uobj.tag}>", level)

# ---------------------------------------------------------------------------

(() ->

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, HtmlMapper)

	treeTester = new MyTester()

	# ----------------------------------------------------------

	treeTester.equal 1388, """
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

	treeTester.equal 1429, """
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

		beginLevel: (hUser, level) ->
			lTrace.push "S #{level}"
			return

		endLevel: (hUser, level) ->
			lTrace.push "E #{level}"
			return

	class MyTester extends UnitTester

		transformValue: (block) ->

			return map(block, MyMapper)

	treeTester = new MyTester()

	treeTester.equal 1468, """
			abc
				def
			""", """
			abc
				def
			"""

	utest.equal 1476, lTrace, [
		"S 0"
		"S 1"
		"E 1"
		"E 0"
		]

	)()
