# ifdef.test.coffee

import {UnitTester, UnitTesterNorm} from '@jdeighan/unit-tester'
import {
	assert, croak, undef, pass, OL, defined,
	isEmpty, nonEmpty, isString,
	} from '@jdeighan/coffee-utils'
import {
	indentLevel, undented, splitLine, indented,
	} from '@jdeighan/coffee-utils/indent'
import {
	debug, setDebugging,
	} from '@jdeighan/coffee-utils/debug'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {taml} from '@jdeighan/coffee-utils/taml'

import {doMap} from '@jdeighan/mapper'
import {TreeWalker} from '@jdeighan/mapper/tree'
import {TraceWalker} from '@jdeighan/mapper/trace'
import {SimpleMarkDownMapper} from '@jdeighan/mapper/markdown'

simple = new UnitTester()

class WalkTester extends UnitTester

	transformValue: (block) ->

		walker = new TraceWalker(import.meta.url, block)
		return walker.walk()

tester = new WalkTester()

# ..........................................................

tester.equal 35, """
		abc
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		END VISIT 0 'abc'
		END WALK
		"""

tester.equal 44, """
		abc
		def
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		END VISIT 0 'abc'
		VISIT     0 'def'
		END VISIT 0 'def'
		END WALK
		"""

tester.equal 56, """
		abc
			def
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		VISIT     1 'def'
		END VISIT 1 'def'
		END VISIT 0 'abc'
		END WALK
		"""

tester.equal 68, """
		abc
		#ifdef NOPE
			def
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		END VISIT 0 'abc'
		END WALK
		"""
tester.equal 79, """
		abc
		#ifndef NOPE
			def
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		END VISIT 0 'abc'
		VISIT     0 'def'
		END VISIT 0 'def'
		END WALK
		"""

tester.equal 92, """
		#define NOPE 42
		abc
		#ifndef NOPE
			def
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		END VISIT 0 'abc'
		END WALK
		"""

tester.equal 104, """
		#define NOPE 42
		abc
		#ifdef NOPE
			def
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		END VISIT 0 'abc'
		VISIT     0 'def'
		END VISIT 0 'def'
		END WALK
		"""

tester.equal 118, """
		#define NOPE 42
		#define name John
		abc
		#ifdef NOPE
			def
			#ifdef name
				ghi
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		END VISIT 0 'abc'
		VISIT     0 'def'
		END VISIT 0 'def'
		VISIT     0 'ghi'
		END VISIT 0 'ghi'
		END WALK
		"""
