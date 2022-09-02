# RunTimeStack.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {Node} from '@jdeighan/mapper/node'
import {RunTimeStack} from '@jdeighan/mapper/stack'

# ---------------------------------------------------------------------------

stack = new RunTimeStack()
simple.equal 9, stack.len, 0

stack.push new Node('abc', 0, 'file', 1, {hUser: {_parent: {}}})
simple.equal 13, stack.len, 1
simple.like  14, stack.TOS(), {str: 'abc'}

stack.push new Node('def', 0, 'file', 2, {hUser: {_parent: {}}})
simple.equal 17, stack.len, 2
simple.like  18, stack.TOS(), {str: 'def'}

node = stack.pop()
simple.equal 21, stack.len, 1
simple.like  22, stack.TOS(), {str: 'abc'}
