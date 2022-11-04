// Generated by CoffeeScript 2.7.0
  // RunTimeStack.coffee
import {
  LOG,
  LOGVALUE,
  assert,
  croak
} from '@jdeighan/base-utils';

import {
  undef,
  pass,
  defined,
  notdefined,
  OL,
  isString,
  isInteger,
  isHash
} from '@jdeighan/coffee-utils';

import {
  Node
} from '@jdeighan/mapper/node';

// ---------------------------------------------------------------------------
export var RunTimeStack = class RunTimeStack {
  constructor() {
    this.lStack = []; // contains Node objects
    this.len = 0;
  }

  // ..........................................................
  replaceTOS(hNode) {
    this.checkNode(hNode);
    this.lStack[this.len - 1] = hNode;
  }

  // ..........................................................
  push(hNode) {
    this.checkNode(hNode);
    this.lStack.push(hNode);
    this.len += 1;
  }

  // ..........................................................
  pop() {
    var hNode;
    assert(this.len > 0, "pop() on empty stack");
    hNode = this.lStack.pop();
    this.checkNode(hNode);
    this.len -= 1;
    return hNode;
  }

  // ..........................................................
  isEmpty() {
    return this.len === 0;
  }

  // ..........................................................
  nonEmpty() {
    return this.len > 0;
  }

  // ..........................................................
  TOS() {
    var hNode;
    if (this.len > 0) {
      hNode = this.lStack[this.len - 1];
      this.checkNode(hNode);
      return hNode;
    } else {
      return undef;
    }
  }

  // ..........................................................
  checkNode(hNode) {
    // --- Each node should have a key named hUser - a hash
    //     hUser should have a key named _parent - a hash
    assert(hNode instanceof Node, "not a Node");
    assert(isHash(hNode.hUser), "missing hUser key");
    assert(isHash(hNode.hUser._parent), "missing _parent key");
  }

};
