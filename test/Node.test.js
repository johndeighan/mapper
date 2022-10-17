// Generated by CoffeeScript 2.7.0
// Node.test.coffee
var node;

import {
  assert,
  croak,
  setDebugging,
  setLogger,
  LOG
} from '@jdeighan/exceptions';

import {
  tester
} from '@jdeighan/unit-tester';

import {
  OL
} from '@jdeighan/coffee-utils';

import {
  Node
} from '@jdeighan/mapper/node';

// ---------------------------------------------------------------------------
node = new Node('div', 0, import.meta.url, 1);

node.incLevel();

tester.equal(13, node.getLine("   "), "   div");
