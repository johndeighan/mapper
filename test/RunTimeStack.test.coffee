# RunTimeStack.test.coffee

import {UnitTester, tester} from '@jdeighan/unit-tester'
import {Node} from '@jdeighan/mapper/node'
import {RunTimeStack} from '@jdeighan/mapper/stack'

# ---------------------------------------------------------------------------

stack = new RunTimeStack()
tester.equal 9, stack.len, 0

stack.push new Node('abc', 0, 'file', 1, {hUser: {_parent: {}}})
tester.equal 13, stack.len, 1
tester.like  14, stack.TOS(), {str: 'abc'}

stack.push new Node('def', 0, 'file', 2, {hUser: {_parent: {}}})
tester.equal 17, stack.len, 2
tester.like  18, stack.TOS(), {str: 'def'}

node = stack.pop()
tester.equal 21, stack.len, 1
tester.like  22, stack.TOS(), {str: 'abc'}
