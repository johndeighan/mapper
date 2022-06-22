# allMapped.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {
	assert, croak, undef, pass, OL, defined,
	isEmpty, nonEmpty, isString, eval_expr,
	} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {blockToArray} from '@jdeighan/coffee-utils/block'

import {doDebugHereDoc} from '@jdeighan/mapper/heredoc'
import {TreeWalker, TraceWalker} from '@jdeighan/mapper/tree'

simple = new UnitTester()

# ---------------------------------------------------------------------------
# Test TreeWalker.allMapped()

(() ->
	class Tester extends UnitTester

		transformValue: (block) ->

			walker = new TreeWalker(import.meta.url, block)
			lUserObjects = []
			for uobj from walker.allMapped()
				lUserObjects.push uobj
			return lUserObjects

	tester = new Tester()

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from simple line

	tester.equal 37, """
			# --- comment, followed by blank line

			abc
			""", [
			{
				lineNum: 3
				level:   0
				item:    'abc'
				},
			]

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from simple line

	tester.equal 53, """
			# --- comment, followed by blank line

			abc

			# -- this should be removed

			def
			""", [
			{
				lineNum: 3
				level:   0
				item:    'abc'
				},
			{
				lineNum: 7
				level:   0
				item:    'def'
				},
			]

	# ------------------------------------------------------------------------
	# --- level

	tester.equal 77, """
			abc
				def
					ghi
				uvw
			xyz
			""", [
			{
				lineNum: 1
				level:   0
				item:    'abc'
				},
			{
				lineNum: 2
				level:   1
				item:    'def'
				},
			{
				lineNum: 3
				level:   2
				item:    'ghi'
				},
			{
				lineNum: 4
				level:   1
				item:    'uvw'
				},
			{
				lineNum: 5
				level:   0
				item:    'xyz'
				},
			]
	)()

# ---------------------------------------------------------------------------
# Create a more compact tester

(() ->
	class Tester extends UnitTester

		constructor: () ->

			super()
			@debug = false

		transformValue: (block) ->

			walker = new TreeWalker(import.meta.url, block)
			lUserObjects = []
			for uobj from walker.allMapped()
				lUserObjects.push uobj
			if @debug
				LOG 'lUserObjects', lUserObjects
			return lUserObjects

		getUserObj: (line) ->

			pos0 = line.indexOf(' ')
			assert (pos0 > 0), "Missing 1st space char"
			pos1 = line.indexOf(' ', pos0 + 1)
			assert (pos1 > 0), "Missing 2nd space char"
			lineNum = parseInt(line.substring(0, pos0))
			level = parseInt(line.substring(pos0+1, pos1))
			item = line.substring(pos1+1)

			if (item[0] == '{')
				item = eval_expr(item)

			return {
				lineNum
				level
				item
				}

		transformExpected: (block) ->

			lExpected = []
			for line in blockToArray(block)
				if @debug
					LOG 'line', line
				lExpected.push @getUserObj(line)
			if @debug
				LOG 'lExpected', lExpected
			return lExpected

		doDebug: (flag=true) ->

			@debug = flag
			return

	tester = new Tester()


	# ------------------------------------------------------------------------

	tester.equal 173, """
			# --- comment, followed by blank line

			abc
				def
					ghi
			""", """
			3 0 abc
			4 1 def
			5 2 ghi
			"""

	# ------------------------------------------------------------------------
	# --- const replacement

	tester.equal 188, """
			#define name John Deighan
			abc
			__name__
			""", """
			2 0 abc
			3 0 John Deighan
			"""

	# ------------------------------------------------------------------------
	# --- extension lines

	tester.equal 200, """
			abc
					&& def
					&& ghi
			xyz
			""", """
			1 0 abc && def && ghi
			4 0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - block (default)

	tester.equal 213, """
			func(<<<)
				abc
				def

			xyz
			""", """
			1 0 func("abc\\ndef")
			5 0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - block (explicit)

	tester.equal 227, """
			func(<<<)
				===
				abc
				def

			xyz
			""", """
			1 0 func("abc\\ndef")
			6 0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - oneline

	tester.equal 242, """
			func(<<<)
				...
				abc
				def

			xyz
			""", """
			1 0 func("abc def")
			6 0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - oneline

	tester.equal 257, """
			func(<<<)
				...abc
				   def

			xyz
			""", """
			1 0 func("abc def")
			5 0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - TAML

	tester.equal 271, """
			func(<<<)
				---
				- abc
				- def

			xyz
			""", """
			1 0 func(["abc","def"])
			6 0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- HEREDOC handling - function

	tester.equal 286, """
			handleClick(<<<)
				(event) ->
					event.preventDefault()
					alert('clicked')
					return

			xyz
			""", """
			1 0 handleClick((function(event) { event.preventDefault(); alert('clicked'); });)
			7 0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- using __END__

	tester.equal 302, """
			abc
			def
			__END__
			ghi
			jkl
			""", """
			1 0 abc
			2 0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with no value

	tester.equal 316, """
			#ifdef mobile
				abc
			def
			""", """
			1 0 {cmd: 'ifdef', name: 'mobile'}
			2 1 abc
			3 0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value

	tester.equal 329, """
			#ifdef mobile samsung
				abc
			def
			""", """
			1 0 {cmd: 'ifdef', name: 'mobile', value: 'samsung'}
			2 1 abc
			3 0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with no value

	tester.equal 342, """
			#ifndef mobile
				abc
			def
			""", """
			1 0 {cmd: 'ifndef', name: 'mobile'}
			2 1 abc
			3 0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with a value

	tester.equal 355, """
			#ifndef mobile samsung
				abc
			def
			""", """
			1 0 {cmd: 'ifndef', name: 'mobile', value: 'samsung'}
			2 1 abc
			3 0 def
			"""

	# ------------------------------------------------------------------------
	# --- nested commands

	tester.equal 368, """
			#ifdef mobile samsung
				#ifdef large
					abc
			""", """
			1 0 {cmd: 'ifdef', name: 'mobile', value: 'samsung'}
			2 1 {cmd: 'ifdef', name: 'large'}
			3 2 abc
			"""

	)()
