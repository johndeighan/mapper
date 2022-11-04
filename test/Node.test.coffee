# Node.test.coffee

import {
	assert, croak, setDebugging, setLogger, LOG,
	} from '@jdeighan/base-utils'
import {utest} from '@jdeighan/unit-tester'
import {OL} from '@jdeighan/coffee-utils'

import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------

node = new Node('div', 0, import.meta.url, 1)
node.incLevel()

utest.equal 13, node.getLine("   "), "   div"
