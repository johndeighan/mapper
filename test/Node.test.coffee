# Node.test.coffee

import {OL} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {equal, like} from '@jdeighan/base-utils/utest'

import {Node} from '@jdeighan/mapper/node'

# ---------------------------------------------------------------------------

node = new Node({
	str: 'div'
	level: 0
	source: import.meta.url
	lineNum: 1
	})
node.incLevel()

like node, {
	str: 'div'
	level: 1
	source: import.meta.url
	lineNum: 1
	srcLevel: 0
	}
equal node.getLine({oneIndent: "=> "}), "=> div"

equal new Node({str: 'abc', level:1}).getLine(),
	"\tabc"
equal new Node({str: 'abc', level:2}).getLine({oneIndent:'  '}),
	"    abc"
equal new Node({str: 'abc', level:0}).getLine(),
	"abc"
equal new Node({str: 'abc', level:3}).getLine(),
	"\t\t\tabc"
