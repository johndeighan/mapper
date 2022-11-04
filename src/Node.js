// Generated by CoffeeScript 2.7.0
  // Node.coffee
import {
  LOG,
  LOGVALUE,
  assert,
  croak
} from '@jdeighan/exceptions';

import {
  dbg,
  dbgEnter,
  dbgReturn
} from '@jdeighan/exceptions/debug';

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
  constructor(str, level, source, lineNum, hData) {
    this.str = str;
    this.level = level;
    this.source = source;
    this.lineNum = lineNum;
    assert(isString(this.str), `str ${OL(this.str)} not a string`);
    assert(isInteger(this.level, {
      min: 0
    }), `level ${OL(this.level)} not an integer`);
    assert(isString(this.source), `source ${OL(this.source)} not a string`);
    assert(isInteger(this.lineNum, {
      min: 1
    }), `lineNum ${OL(this.lineNum)} not an integer`);
    // --- level may later be adjusted, but srcLevel should be const
    this.srcLevel = this.level;
    Object.assign(this, hData);
  }

  // ..........................................................
  // --- used when '#include <file>' has indentation
  incLevel(n = 1) {
    this.level += n;
  }

  // ..........................................................
  isMapped() {
    return defined(this.uobj);
  }

  // ..........................................................
  notMapped() {
    return notdefined(this.uobj);
  }

  // ..........................................................
  getLine(oneIndent) {
    return indented(this.str, this.level, oneIndent);
  }

};
