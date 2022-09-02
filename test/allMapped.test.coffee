# allMapped.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, OL, defined, isArray,
	isEmpty, nonEmpty, isString, eval_expr,
	} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {blockToArray} from '@jdeighan/coffee-utils/block'

import {TreeWalker} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------
# Test TreeWalker.allMapped()

(() ->
	class MapTester extends UnitTester

		transformValue: (block) ->

			walker = new TreeWalker(import.meta.url, block)
			lUserObjects = []
			for uobj from walker.allMapped()
				lUserObjects.push uobj
			assert isArray(lUserObjects), "lUserObjects is #{OL(lUserObjects)}"
			return lUserObjects

	tester = new MapTester()

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from simple line

	tester.like 37, """
			# --- comment, followed by blank line xxx

			abc
			""", [
			{str: 'abc', level: 0},
			]

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from simple line

	tester.like 49, """
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

	tester.like 65, """
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
# Create a more compact tester

(() ->
	class MapTester extends UnitTester

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
			assert isArray(lUserObjects), "lUserObjects is #{OL(lUserObjects)}"
			return lUserObjects

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

	tester = new MapTester()

	# ------------------------------------------------------------------------

	tester.like 135, """
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

	tester.like 148, """
			#define name John Deighan
			abc
			__name__
			""", """
			0 abc
			0 John Deighan
			"""

	# ------------------------------------------------------------------------
	# --- extension lines

	tester.like 160, """
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

	tester.like 173, """
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

	tester.like 187, """
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

	tester.like 202, """
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

	tester.like 217, """
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

	tester.like 231, """
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

	tester.like 246, """
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

	tester.like 262, """
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

	tester.like 277, """
			#ifdef mobile
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with no value - value defined

	tester.like 288, """
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

	tester.like 302, """
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined, but different

	tester.like 313, """
			#define mobile apple
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined and same

	tester.like 325, """
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

	tester.like 339, """
			#ifndef mobile
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with no value - defined

	tester.like 351, """
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

	tester.like 364, """
			#ifndef mobile samsung
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with a value - defined, but different

	tester.like 376, """
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

	tester.like 389, """
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

	tester.like 402, """
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

	tester.like 416, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifdef large
					abc
			""", """
			"""

	# --- nested commands

	tester.like 427, """
			#define mobile samsung
			#define large anything
			#ifdef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# --- nested commands

	tester.like 438, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# ----------------------------------------------------------
	# --- nested commands - every combination

	tester.like 450, """
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

	tester.like 466, """
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

	tester.like 480, """
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

	tester.like 493, """
			#ifdef mobile samsung
				abc
				#ifdef large
					def
			ghi
			""", """
			0 ghi
			"""

	)()
