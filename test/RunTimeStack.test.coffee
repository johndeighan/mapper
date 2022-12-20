# RunTimeStack.test.coffee

import {UnitTester, utest} from '@jdeighan/unit-tester'
import {Node} from '@jdeighan/mapper/node'
import {RunTimeStack} from '@jdeighan/mapper/stack'

# ---------------------------------------------------------------------------

stack = new RunTimeStack()
utest.equal 10, stack.size(), 0

stack.push new Node({str: 'abc', level: 0, hUser: {_parent: {}}})
utest.equal 13, stack.size(), 1
utest.like  14, stack.TOS(), {str: 'abc'}

stack.push new Node({str: 'def', level: 0, hUser: {_parent: {}}})
utest.equal 17, stack.size(), 2
utest.like  18, stack.TOS(), {str: 'def'}

node = stack.pop()
utest.equal 21, stack.size(), 1
utest.like  22, stack.TOS(), {str: 'abc'}
