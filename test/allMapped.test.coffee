# allMapped.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {
	assert, croak, undef, pass, OL, defined,
	isEmpty, nonEmpty, isString, eval_expr,
	} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {blockToArray} from '@jdeighan/coffee-utils/block'

import {addStdHereDocTypes} from '@jdeighan/mapper/heredoc'
import {TreeWalker, TraceWalker} from '@jdeighan/mapper/tree'

addStdHereDocTypes()

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

	tester.equal 46, """
			# --- comment, followed by blank line

			abc
			""", [
			{
				item:  'abc'
				level: 0
				},
			]

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from simple line

	tester.equal 61, """
			# --- comment, followed by blank line

			abc

			# -- this should be removed

			def
			""", [
			{
				item:  'abc'
				level: 0
				},
			{
				item:  'def'
				level: 0
				},
			]

	# ------------------------------------------------------------------------
	# --- level

	tester.equal 83, """
			abc
				def
					ghi
				uvw
			xyz
			""", [
			{
				item:    'abc'
				level:   0
				},
			{
				item:    'def'
				level:   1
				},
			{
				item:    'ghi'
				level:   2
				},
			{
				item:    'uvw'
				level:   1
				},
			{
				item:    'xyz'
				level:   0
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
			assert (pos > 0), "Missing 1st space char in #{OL(line)}"
			level = parseInt(line.substring(0, pos))
			item = line.substring(pos+1).replace(/\\N/g, '\n').replace(/\\T/g, '\t')

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

	tester.equal 167, """
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

	tester.equal 182, """
			#define name John Deighan
			abc
			__name__
			""", """
			0 abc
			0 John Deighan
			"""

	# ------------------------------------------------------------------------
	# --- extension lines

	tester.equal 194, """
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

	tester.equal 207, """
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

	tester.equal 221, """
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

	tester.equal 236, """
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

	tester.equal 251, """
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

	tester.equal 265, """
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

	tester.equal 280, """
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

	tester.equal 296, """
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

	tester.equal 311, """
			#ifdef mobile
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with no value - value defined

	tester.equal 322, """
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

	tester.equal 336, """
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined, but different

	tester.equal 347, """
			#define mobile apple
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined and same

	tester.equal 359, """
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

	tester.equal 373, """
			#ifndef mobile
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with no value - defined

	tester.equal 385, """
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

	tester.equal 398, """
			#ifndef mobile samsung
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with a value - defined, but different

	tester.equal 410, """
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

	tester.equal 423, """
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

	tester.equal 436, """
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

	tester.equal 450, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifdef large
					abc
			""", """
			"""

	# --- nested commands

	tester.equal 461, """
			#define mobile samsung
			#define large anything
			#ifdef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# --- nested commands

	tester.equal 472, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# ----------------------------------------------------------
	# --- nested commands - every combination

	tester.equal 484, """
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

	tester.equal 500, """
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

	tester.equal 514, """
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

	tester.equal 527, """
			#ifdef mobile samsung
				abc
				#ifdef large
					def
			ghi
			""", """
			0 ghi
			"""

	)()
