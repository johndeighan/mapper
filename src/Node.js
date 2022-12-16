// Generated by CoffeeScript 2.7.0
  // Node.coffee
import {
  LOG,
  LOGVALUE,
  assert,
  croak
} from '@jdeighan/base-utils';

import {
  dbg,
  dbgEnter,
  dbgReturn
} from '@jdeighan/base-utils/debug';

import {
  undef,
  pass,
  defined,
  notdefined,
  OL,
  isString,
  isInteger
} from '@jdeighan/coffee-utils';

import {
  indented,
  indentLevel,
  splitPrefix
} from '@jdeighan/coffee-utils/indent';

// ---------------------------------------------------------------------------
export var Node = class Node {
  constructor(hNodeDesc) {
    this.checkNode(hNodeDesc);
    Object.assign(this, hNodeDesc);
    this.checkNode(this);
    // --- level may later be adjusted, but srcLevel should be const
    this.srcLevel = this.level;
  }

  // ..........................................................
  checkNode(h) {
    assert(isString(h.str), `str ${OL(h.str)} not a string`);
    assert(isInteger(h.level, {
      min: 0
    }), `level ${OL(h.level)} not an integer`);
    assert(isString(h.source), `source ${OL(this.source)} not a string`);
    assert(isInteger(h.lineNum, {
      min: 1
    }), `lineNum ${OL(h.lineNum)} not an integer`);
  }

  // ..........................................................
  // --- used when '#include <file>' has indentation
  incLevel(n = 1) {
    this.level += n;
  }

  // ..........................................................
  getLine(oneIndent = "\t") {
    return indented(this.str, this.level, oneIndent);
  }

};
