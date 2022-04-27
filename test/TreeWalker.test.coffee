# TreeWalker.test.coffee

import assert from 'assert'
import CoffeeScript from 'coffeescript'

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {undef, words} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {taml} from '@jdeighan/mapper/taml'
import {ASTWalker, TreeStringifier} from '@jdeighan/mapper/walker'

simple = new UnitTesterNorm()
dumpfile = "c:/Users/johnd/string-input/test/ast.txt"

(() ->

	class TreeTester extends UnitTester

		transformValue: (tree) ->
			stringifier = new TreeStringifier(tree, {node: undef})
			return stringifier.get()

	tester = new TreeTester()

	# ------------------------------------------------------------------------

	tree = taml("""
		---
		-
			name: John
			age: 68
			subtree:
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

	tester.equal 48, tree, """
			{"name":"John","age":68}
				{"name":"Judy","age":24}
				{"name":"Bob","age":34}
			{"name":"Lewis","age":40}
			"""

	# ------------------------------------------------------------------------
	# Test creating explicit nodes

	tree2 = taml("""
		---
		-
			node:
				name: John
				age: 68
			subtree:
				-
					node:
						name: Judy
						age: 24
				-
					node:
						name: Bob
						age: 34
		-
			node:
				name: Lewis
				age: 40
		""")

	tester.equal 79, tree2, """
			{"name":"John","age":68}
				{"name":"Judy","age":24}
				{"name":"Bob","age":34}
			{"name":"Lewis","age":40}
			"""
	# ------------------------------------------------------------------------
	# Test mixing explicit and implicit nodes

	tree2 = taml("""
		---
		-
			node:
				name: John
				age: 68
			subtree:
				-
					name: Judy
					age: 24
				-
					node:
						name: Bob
						age: 34
		-
			node:
				name: Lewis
				age: 40
		""")

	tester.equal 108, tree2, """
			{"name":"John","age":68}
				{"name":"Judy","age":24}
				{"name":"Bob","age":34}
			{"name":"Lewis","age":40}
			"""
	)()

(() ->

	class ASTTester extends UnitTesterNorm

		transformValue: (code) ->

			ast = CoffeeScript.compile code, {ast: true}
			assert ast?, "ASTTester(): ast is empty"
			walker = new ASTWalker(ast)
			hSymbols = walker.getSymbols()  # has keys imported, used, needed
			return hSymbols

	tester = new ASTTester()

	# ------------------------------------------------------------------------

	tester.equal 132, """
			import {undef, pass} from '@jdeighan/coffee-utils'
			import {slurp, barf} from '@jdeighan/coffee-utils/fs'

			try
				contents = slurp('myfile.txt')
			if (contents == undef)
				print "File does not exist"
			""", {
			lImported: words('undef pass slurp barf'),
			lUsed: words('slurp undef print'),
			lNeeded: ['print'],
			}

	# ------------------------------------------------------------------------

	tester.equal 148, """
			import {pass} from '@jdeighan/coffee-utils'
			import {barf} from '@jdeighan/coffee-utils/fs'

			try
				contents = slurp('myfile.txt')
			if (contents == undef)
				print "File does not exist"
			""", {
			lImported: words('pass barf'),
			lUsed: words('slurp undef print'),
			lNeeded: words('slurp undef print'),
			}

	# ------------------------------------------------------------------------

	tester.equal 164, """
			try
				contents = slurp('myfile.txt')
			if (contents == undef)
				print "File does not exist"
			""", {
			lImported: [],
			lUsed: words('slurp undef print'),
			lNeeded: words('slurp undef print'),
			}
	)()
