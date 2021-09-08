# tree.test.coffee

import {log, undef, setUnitTesting, escapeStr} from '@jdeighan/coffee-utils'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {debug} from '@jdeighan/coffee-utils/debug'
import {taml} from '@jdeighan/string-input/convert'
import {TreeWalker, TreeStringifier} from '@jdeighan/string-input/tree'

setUnitTesting(true)
simple = new UnitTester()

# ---------------------------------------------------------------------------

class TreeTester extends UnitTester

	transformValue: (tree) ->
		debug "enter transformValue()"
		debug tree, "TREE:"
		stringifier = new TreeStringifier(tree)
		str = stringifier.get()
		debug "return '#{escapeStr(str)}' from tansformValue()"
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
