# walk.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {assert, croak, undef, pass} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'

import {doMap} from '@jdeighan/mapper'
import {TraceWalker} from '@jdeighan/mapper/trace'

simple = new UnitTester()

# ---------------------------------------------------------------------------
# Test TreeWalker.walk()

(() ->
	class Tester extends UnitTester

		transformValue: (block) ->
			return doMap(TraceWalker, import.meta.url, block)

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
			VISIT     0 'abc'
			END VISIT 0 'abc'
			END WALK
			"""

	tester.equal 38, """
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

	tester.equal 50, """
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

	tester.equal 62, """
			# this is a unit test
			abc

				def
			""", """
			BEGIN WALK
			VISIT     0 '#˳this˳is˳a˳unit˳test' (comment)
			END VISIT 0 '#˳this˳is˳a˳unit˳test' (comment)
			VISIT     0 'abc'
			VISIT     1 'def'
			END VISIT 1 'def'
			END VISIT 0 'abc'
			END WALK
			"""

	tester.equal 78, """
			# this is a unit test
			abc
			__END__
				def
			""", """
			BEGIN WALK
			VISIT     0 '#˳this˳is˳a˳unit˳test' (comment)
			END VISIT 0 '#˳this˳is˳a˳unit˳test' (comment)
			VISIT     0 'abc'
			END VISIT 0 'abc'
			END WALK
			"""

	tester.equal 92, """
			# this is a unit test
			abc
					def
			""", """
			BEGIN WALK
			VISIT     0 '#˳this˳is˳a˳unit˳test' (comment)
			END VISIT 0 '#˳this˳is˳a˳unit˳test' (comment)
			VISIT     0 'abc˳def'
			END VISIT 0 'abc˳def'
			END WALK
			"""

	)()

# ---------------------------------------------------------------------------
# Test custom TraceWalker

(() ->
	class MyTraceWalker extends TraceWalker

		mapStr: (str, level) ->

			return {text: str}

	class Tester extends UnitTester

		transformValue: (block) ->
			return doMap(MyTraceWalker, import.meta.url, block)

	tester = new Tester()

	tester.equal 124, """
			abc
			""", """
			BEGIN WALK
			VISIT     0 {"text":"abc"}
			END VISIT 0 {"text":"abc"}
			END WALK
			"""

)()
