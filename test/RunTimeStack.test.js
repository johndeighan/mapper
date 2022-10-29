// Generated by CoffeeScript 2.7.0
// RunTimeStack.test.coffee
var node, stack;

import {
  UnitTester,
  utest
} from '@jdeighan/unit-tester';

import {
  Node
} from '@jdeighan/mapper/node';

import {
  RunTimeStack
} from '@jdeighan/mapper/stack';

// ---------------------------------------------------------------------------
stack = new RunTimeStack();

utest.equal(9, stack.len, 0);

stack.push(new Node('abc', 0, 'file', 1, {
  hUser: {
    _parent: {}
  }
}));

utest.equal(13, stack.len, 1);

utest.like(14, stack.TOS(), {
  str: 'abc'
});

stack.push(new Node('def', 0, 'file', 2, {
  hUser: {
    _parent: {}
  }
}));

utest.equal(17, stack.len, 2);

utest.like(18, stack.TOS(), {
  str: 'def'
});

node = stack.pop();

utest.equal(21, stack.len, 1);

utest.like(22, stack.TOS(), {
  str: 'abc'
});
