# walker.test.coffee

import assert from 'assert'
import CoffeeScript from 'coffeescript'

import {UnitTester} from '@jdeighan/unit-tester'
import {undef, words} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {ASTWalker} from '@jdeighan/string-input/walker'

simple = new UnitTester()
dumpfile = "c:/Users/johnd/string-input/test/ast.txt"

# ---------------------------------------------------------------------------

class ASTTester extends UnitTester

	transformValue: (code) ->

		ast = CoffeeScript.compile code, {ast: true}
		assert ast?, "ASTTester(): ast is empty"
		walker = new ASTWalker(ast)
		hSymbols = walker.getSymbols()  # has keys imported, used, needed
		return hSymbols

export tester = new ASTTester()

# ----------------------------------------------------------------------------

tester.equal 33, """
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

# ----------------------------------------------------------------------------

tester.equal 49, """
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

# ----------------------------------------------------------------------------

tester.equal 65, """
		try
			contents = slurp('myfile.txt')
		if (contents == undef)
			print "File does not exist"
		""", {
		lImported: [],
		lUsed: words('slurp undef print'),
		lNeeded: words('slurp undef print'),
		}
