# RunTimeStack.test.coffee

import {equal, like} from '@jdeighan/base-utils/utest'

import {Node} from '@jdeighan/mapper/node'
import {RunTimeStack} from '@jdeighan/mapper/stack'

# ---------------------------------------------------------------------------

stack = new RunTimeStack()
equal stack.size(), 0

stack.push new Node({
	str: 'abc'
	level: 0
	hEnv: {}
	})
equal stack.size(), 1
like  stack.TOS(), {str: 'abc'}

stack.push new Node({
	str: 'def'
	level: 0
	hEnv: {}
	})
equal stack.size(), 2
like  stack.TOS(), {str: 'def'}

node = stack.pop()
equal stack.size(), 1
like  stack.TOS(), {str: 'abc'}
