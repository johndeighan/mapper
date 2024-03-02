# traceNodes.test.coffee

import {setDebugging} from '@jdeighan/base-utils/debug'
import {echoLogsByDefault} from '@jdeighan/base-utils/log'
import {u, equal} from '@jdeighan/base-utils/utest'
import {getTrace} from '@jdeighan/mapper/tree'

echoLogsByDefault false

# ---------------------------------------------------------------------------

u.transformValue = (block) => return getTrace(block)

equal "", """
		BEGIN WALK
		END WALK
		"""

equal """
		abc
		""", """
		BEGIN WALK
		BEGIN LEVEL 0
		VISIT 0 'abc'
		END VISIT 0 'abc'
		END LEVEL 0
		END WALK
		"""

equal """
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

equal """
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

equal """
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

equal """
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
