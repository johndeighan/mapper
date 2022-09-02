# walk.test.coffee

import {UnitTesterNorm, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {undef, pass} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'

import {map} from '@jdeighan/mapper'
import {TraceWalker} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------
# Test TreeWalker.walk()

(() ->
	class Tester extends UnitTesterNorm

		transformValue: (block) ->
			return map(import.meta.url, block, TraceWalker)

	tester = new Tester()

	tester.equal 23, """
			""", """
			BEGIN WALK
			END WALK
			"""

	tester.equal 29, """
			abc
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc'
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	tester.equal 38, """
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

	tester.equal 50, """
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

	tester.equal 62, """
			# this is a unit test
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

	tester.equal 78, """
			# this is a unit test
			abc
			__END__
				def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc'
			END VISIT 0 'abc'
			END LEVEL 0
			END WALK
			"""

	tester.equal 92, """
			# this is a unit test
			abc
					def
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 'abc˳def'
			END VISIT 0 'abc˳def'
			END LEVEL 0
			END WALK
			"""

	)()

# ---------------------------------------------------------------------------
# Test custom TraceWalker

(() ->
	class MyTraceWalker extends TraceWalker

		mapNode: (hNode) ->

			return {text: hNode.str}

	class Tester extends UnitTesterNorm

		transformValue: (block) ->
			return map(import.meta.url, block, MyTraceWalker)

	tester = new Tester()

	tester.equal 124, """
			abc
			""", """
			BEGIN WALK
			BEGIN LEVEL 0
			VISIT     0 {"text":"abc"}
			END VISIT 0 {"text":"abc"}
			END LEVEL 0
			END WALK
			"""

)()
