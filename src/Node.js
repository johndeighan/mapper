// Generated by CoffeeScript 2.7.0
  // Node.coffee
import {
  assert,
  error,
  croak
} from '@jdeighan/unit-tester/utils';

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
    assert(isString(this.str), `str is ${OL(this.str)}`);
    assert(isInteger(this.level, {
      min: 0
    }), `level is ${OL(this.level)}`);
    assert(isString(this.source), `source is ${OL(this.source)}`);
    assert(isInteger(this.lineNum, {
      min: 0
    }), `lineNum is ${OL(this.lineNum)}`);
    // --- level may later be adjusted, but srcLevel should be const
    this.srcLevel = this.level;
    Object.assign(this, hData);
  }

  // ..........................................................
  // --- used when '#include <file>' has indentation
  incLevel(n) {
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
