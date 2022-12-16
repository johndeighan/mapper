# Node.test.coffee

import {
	assert, croak, setDebugging, LOG,
	} from '@jdeighan/base-utils'
import {utest} from '@jdeighan/unit-tester'
import {OL} from '@jdeighan/coffee-utils'

import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------

node = new Node({
	str: 'div'
	level: 0
	source: import.meta.url
	lineNum: 1
	})
node.incLevel()

utest.like 21, node, {
	str: 'div'
	level: 1
	source: import.meta.url
	lineNum: 1
	srcLevel: 0
	}
utest.equal 13, node.getLine("=> "), "=> div"
