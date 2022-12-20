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
utest.equal 28, node.getLine({oneIndent: "=> "}), "=> div"

utest.equal 30, new Node({str: 'abc', level:1}).getLine(),
	"\tabc"
utest.equal 32, new Node({str: 'abc', level:2}).getLine({oneIndent:'  '}),
	"    abc"
utest.equal 34, new Node({str: 'abc', level:0}).getLine(),
	"abc"
utest.equal 36, new Node({str: 'abc', level:3}).getLine(),
	"\t\t\tabc"
