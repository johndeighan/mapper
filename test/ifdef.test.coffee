# ifdef.test.coffee

import {UnitTester, UnitTesterNorm, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, OL, defined,
	isEmpty, nonEmpty, isString,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {LOG} from '@jdeighan/coffee-utils/log'
import {
	debug, setDebugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {taml} from '@jdeighan/coffee-utils/taml'

import {TreeWalker} from '@jdeighan/mapper/tree'

class WalkTester extends UnitTesterNorm

	transformValue: (block) ->

		walker = new TreeWalker(import.meta.url, block)
		hOptions = {
			traceNodes: true
			}
		[result, trace] = walker.walk(hOptions)
		return trace

tester = new WalkTester()

# ..........................................................

tester.equal 34, """
		abc
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT       0 'abc'
		END VISIT   0 'abc'
		END LEVEL   0
		END WALK
		"""

tester.equal 43, """
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

tester.equal 55, """
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

tester.equal 67, """
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

tester.equal 78, """
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

tester.equal 91, """
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

tester.equal 103, """
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

tester.equal 117, """
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
