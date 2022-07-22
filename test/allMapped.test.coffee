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
import {TreeWalker} from '@jdeighan/mapper/tree'
import {TraceWalker} from '@jdeighan/mapper/trace'

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

	tester.like 46, """
			# --- comment, followed by blank line

			abc
			""", [
			{
				item:  '# --- comment, followed by blank line'
				level: 0
				type: 'comment'
				},
			{
				item:  'abc'
				level: 0
				},
			]

	# ------------------------------------------------------------------------
	# --- remove comments and blank lines
	#     create user object from simple line

	tester.like 61, """
			# --- comment, followed by blank line

			abc

			# --- this should not be removed

			def
			""", [
			{
				item:  '# --- comment, followed by blank line'
				level: 0
				type: 'comment'
				},
			{
				item:  'abc'
				level: 0
				},
			{
				item:  '# --- this should not be removed'
				level: 0
				type: 'comment'
				},
			{
				item:  'def'
				level: 0
				},
			]

	# ------------------------------------------------------------------------
	# --- level

	tester.like 83, """
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

	tester.like 167, """
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

	tester.like 182, """
			#define name John Deighan
			abc
			__name__
			""", """
			0 abc
			0 John Deighan
			"""

	# ------------------------------------------------------------------------
	# --- extension lines

	tester.like 194, """
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

	tester.like 207, """
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

	tester.like 221, """
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

	tester.like 236, """
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

	tester.like 251, """
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

	tester.like 265, """
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

	tester.like 280, """
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

	tester.like 296, """
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

	tester.like 311, """
			#ifdef mobile
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with no value - value defined

	tester.like 322, """
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

	tester.like 336, """
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined, but different

	tester.like 347, """
			#define mobile apple
			#ifdef mobile samsung
				abc
			def
			""", """
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifdef with a value - value defined and same

	tester.like 359, """
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

	tester.like 373, """
			#ifndef mobile
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with no value - defined

	tester.like 385, """
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

	tester.like 398, """
			#ifndef mobile samsung
				abc
			def
			""", """
			0 abc
			0 def
			"""

	# ------------------------------------------------------------------------
	# --- test #ifndef with a value - defined, but different

	tester.like 410, """
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

	tester.like 423, """
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

	tester.like 436, """
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

	tester.like 450, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifdef large
					abc
			""", """
			"""

	# --- nested commands

	tester.like 461, """
			#define mobile samsung
			#define large anything
			#ifdef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# --- nested commands

	tester.like 472, """
			#define mobile samsung
			#define large anything
			#ifndef mobile samsung
				#ifndef large
					abc
			""", """
			"""

	# ----------------------------------------------------------
	# --- nested commands - every combination

	tester.like 484, """
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

	tester.like 500, """
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

	tester.like 514, """
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

	tester.like 527, """
			#ifdef mobile samsung
				abc
				#ifdef large
					def
			ghi
			""", """
			0 ghi
			"""

	)()
