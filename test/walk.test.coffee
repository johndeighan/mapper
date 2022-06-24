# walk.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {assert, croak, undef, pass} from '@jdeighan/coffee-utils'
import {setDebugging} from '@jdeighan/coffee-utils/debug'

import {doMap} from '@jdeighan/mapper'
import {TraceWalker} from '@jdeighan/mapper/tree'

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
			VISIT 1 0 'abc'
			END VISIT 1 0 'abc'
			END WALK
			"""

	tester.equal 38, """
			abc
			def
			""", """
			BEGIN WALK
			VISIT 1 0 'abc'
			END VISIT 1 0 'abc'
			VISIT 2 0 'def'
			END VISIT 2 0 'def'
			END WALK
			"""

	tester.equal 50, """
			abc
				def
			""", """
			BEGIN WALK
			VISIT 1 0 'abc'
			VISIT 2 1 'def'
			END VISIT 2 1 'def'
			END VISIT 1 0 'abc'
			END WALK
			"""

	tester.equal 62, """
			# this is a unit test
			abc

				def
			""", """
			BEGIN WALK
			VISIT 2 0 'abc'
			VISIT 4 1 'def'
			END VISIT 4 1 'def'
			END VISIT 2 0 'abc'
			END WALK
			"""

	tester.equal 76, """
			# this is a unit test
			abc
			__END__
				def
			""", """
			BEGIN WALK
			VISIT 2 0 'abc'
			END VISIT 2 0 'abc'
			END WALK
			"""

	tester.equal 88, """
			# this is a unit test
			abc
					def
			""", """
			BEGIN WALK
			VISIT 2 0 'abc˳def'
			END VISIT 2 0 'abc˳def'
			END WALK
			"""

	)()

# ---------------------------------------------------------------------------
# Test custom TraceWalker

(() ->
	class MyTraceWalker extends TraceWalker

		mapStr: (str, level, lineNum) ->
			return {text: str}

	class Tester extends UnitTester

		transformValue: (block) ->
			return doMap(MyTraceWalker, import.meta.url, block)

	tester = new Tester()

	tester.equal 117, """
			abc
			""", """
			BEGIN WALK
			VISIT 1 0 {"text":"abc"}
			END VISIT 1 0 {"text":"abc"}
			END WALK
			"""

)()
