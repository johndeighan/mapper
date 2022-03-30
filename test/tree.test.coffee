# tree.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'
import {undef, oneline} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'

import {taml} from '@jdeighan/string-input/taml'
import {TreeWalker, TreeStringifier} from '@jdeighan/string-input/walker'

simple = new UnitTester()

# ---------------------------------------------------------------------------

class TreeTester extends UnitTester

	transformValue: (tree) ->
		debug "enter transformValue()"
		debug "TREE", tree
		stringifier = new TreeStringifier(tree)
		str = stringifier.get()
		debug "return #{oneline(str)} from transformValue()"
		return str

	normalize: (str) -> return str   # disable normalize()

tester = new TreeTester()

# ---------------------------------------------------------------------------

(() ->

	tree = taml("""
		---
		-
			name: John
			age: 68
			body:
				-
					name: Judy
					age: 24
				-
					name: Bob
					age: 34
		-
			name: Lewis
			age: 40
		""")

	tester.equal 49, tree, """
			{"name":"John","age":68}
				{"name":"Judy","age":24}
				{"name":"Bob","age":34}
			{"name":"Lewis","age":40}
			"""
	)()

# ---------------------------------------------------------------------------
