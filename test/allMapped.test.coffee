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
				level:   0
				item:    'abc'
				},
			]

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from simple line

	tester.equal 52, """
			# --- comment, followed by blank line

			abc

			# -- this should be removed

			def
			""", [
			{
				level:   0
				item:    'abc'
				},
			{
				level:   0
				item:    'def'
				},
			]

	# ------------------------------------------------------------------------
	# --- level

	tester.equal 74, """
			abc
				def
					ghi
				uvw
			xyz
			""", [
			{
				level:   0
				item:    'abc'
				},
			{
				level:   1
				item:    'def'
				},
			{
				level:   2
				item:    'ghi'
				},
			{
				level:   1
				item:    'uvw'
				},
			{
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

			pos = line.indexOf(' ')
			assert (pos > 0), "Missing 1st space char"
			level = parseInt(line.substring(0, pos))
			item = line.substring(pos+1)

			if (item[0] == '{')
				item = eval_expr(item)

			return {level, item}

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

	tester.equal 158, """
			# --- comment, followed by blank line

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

	tester.equal 173, """
			#define name John Deighan
			abc
			__name__
			""", """
			0 abc
			0 John Deighan
			"""

	# ------------------------------------------------------------------------
	# --- extension lines

	tester.equal 185, """
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

	tester.equal 198, """
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

	tester.equal 212, """
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

	tester.equal 227, """
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

	tester.equal 242, """
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

	tester.equal 256, """
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

	tester.equal 271, """
			handleClick(<<<)
				(event) ->
					event.preventDefault()
					alert('clicked')
					return

			xyz
			""", """
			0 handleClick((function(event) { event.preventDefault(); alert('clicked'); });)
			0 xyz
			"""

	# ------------------------------------------------------------------------
	# --- using __END__

	tester.equal 287, """
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

	tester.equal 302, """
			#ifdef mobile
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with no value - value defined

	tester.equal 313, """
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

	tester.equal 327, """
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined, but different

	tester.equal 338, """
			#define mobile apple
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined and same

	tester.equal 350, """
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

	tester.equal 364, """
			#ifndef mobile
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with no value - defined

	tester.equal 376, """
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

	tester.equal 389, """
			#ifndef mobile samsung
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with a value - defined, but different

	tester.equal 401, """
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

	tester.equal 414, """
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

	tester.equal 427, """
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

	tester.equal 441, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifdef large
					abc
			""", """
			"""

	# --- nested commands

	tester.equal 452, """
			#define mobile samsung
			#define large anything
			#ifdef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# --- nested commands

	tester.equal 463, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# ----------------------------------------------------------
	# --- nested commands - every combination

	tester.equal 475, """
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

	tester.equal 491, """
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

	tester.equal 505, """
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

	tester.equal 518, """
			#ifdef mobile samsung
				abc
				#ifdef large
					def
			ghi
			""", """
			0 ghi
			"""

	)()
