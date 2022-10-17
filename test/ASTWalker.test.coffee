# ASTWalker.test.coffee

import {tester} from '@jdeighan/unit-tester'

import {getSymbols} from '@jdeighan/mapper/ast'

hInfo = getSymbols("""
	import {toArray, toBlock} from '@jdeighan/coffee-utils'
	import {arrayToBlock} from '@jdeighan/coffee-utils/block'
	export func = () => return 42
	missing(func, toArray)
	""")

tester.equal 13, hInfo.lImported, [
	'toArray'
	'toBlock'
	'arrayToBlock'
	]

tester.equal 18, hInfo.lUsed, [
	'missing'
	'func'
	'toArray'
	]

tester.equal 24, hInfo.lNeeded, [
	'missing'
	]
