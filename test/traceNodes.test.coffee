# traceNodes.test.coffee

import {assert, croak, setDebugging, setLogger} from '@jdeighan/exceptions'
import {UnitTester} from '@jdeighan/unit-tester'
import {untabify} from '@jdeighan/coffee-utils/indent'
import {toBlock} from '@jdeighan/coffee-utils/block'

import {TreeMapper} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------

class TraceTester extends UnitTester

	transformValue: (block) ->

		walker = new TreeMapper(import.meta.url, block)
		walker.walk({logNodes: true})
		return walker.getLog()

	transformExpected: (block) ->

		return untabify(block)

tester = new TraceTester()

# ..........................................................

tester.equal 24, "", """
		BEGIN WALK
		END WALK
		"""

tester.equal 29, """
		abc
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		END LEVEL 0
		END WALK
		"""

tester.equal 40, """
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

tester.equal 54, """
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

tester.equal 70, """
		abc
			def
			ghi
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
			BEGIN LEVEL 1
			VISIT 1 'def'
			END VISIT 1 'def'
			VISIT 1 'ghi'
			END VISIT 1 'ghi'
			END LEVEL 1
		END VISIT 0 'abc'
		END LEVEL 0
		END WALK
		"""

tester.equal 89, """
		abc
			def
			ghi
				jkl
			mno
		pqr
			stu
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
			BEGIN LEVEL 1
			VISIT 1 'def'
			END VISIT 1 'def'
			VISIT 1 'ghi'
				BEGIN LEVEL 2
				VISIT 2 'jkl'
				END VISIT 2 'jkl'
				END LEVEL 2
			END VISIT 1 'ghi'
			VISIT 1 'mno'
			END VISIT 1 'mno'
			END LEVEL 1
		END VISIT 0 'abc'
		VISIT 0 'pqr'
			BEGIN LEVEL 1
			VISIT 1 'stu'
			END VISIT 1 'stu'
			END LEVEL 1
		END VISIT 0 'pqr'
		END LEVEL 0
		END WALK
		"""