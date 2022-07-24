# TraceWalker.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {TraceWalker} from '@jdeighan/mapper/trace'

# ---------------------------------------------------------------------------
# --- Test TraceWalker

class WalkTester extends UnitTester

	transformValue: (block) ->

		walker = new TraceWalker(import.meta.url, block)
		return walker.walk()

tester = new WalkTester()

# ..........................................................

tester.equal 20, """
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

tester.equal 32, """
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

# --- 2 indents is treated as an extension line
tester.equal 45, """
		abc
				def
		""", """
		BEGIN WALK
		VISIT     0 'abc˳def'
		END VISIT 0 'abc˳def'
		END WALK
		"""

tester.equal 55, """
		abc
			def
		ghi
		""", """
		BEGIN WALK
		VISIT     0 'abc'
		VISIT     1 'def'
		END VISIT 1 'def'
		END VISIT 0 'abc'
		VISIT     0 'ghi'
		END VISIT 0 'ghi'
		END WALK
		"""

tester.equal 70, """
		# --- a comment
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
