// Generated by CoffeeScript 2.7.0
  // Getter.coffee
import {
  assert,
  undef,
  pass,
  croak,
  isFunction
} from '@jdeighan/coffee-utils';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

// ---------------------------------------------------------------------------
//   class Getter - get(), unget(item), peek(), eof()
export var Getter = class Getter {
  constructor(obj) {
    // --- obj must be an iterator
    debug("enter Getter()");
    assert(obj[Symbol.iterator], "Getter(): Not an iterator");
    this.iterator = obj[Symbol.iterator]();
    assert(this.iterator.next != null, "Getter(): func, but not an iterator");
    assert(isFunction(this.iterator.next), "Getter(): next not a function");
    this.lLookAhead = [];
    this.atEOF = false;
    debug("return from Getter()");
  }

  // ..........................................................
  hasLookAhead() {
    return this.lLookAhead.length > 0;
  }

  // ..........................................................
  lookahead() {
    if (this.hasLookAhead()) {
      return this.lLookAhead[this.lLookAhead.length - 1];
    } else {
      return undef;
    }
  }

  // ..........................................................
  forceEOF() {
    this.atEOF = true;
  }

  // ..........................................................
  get() {
    var done, item, value;
    debug("enter Getter.get()");
    if (this.hasLookAhead()) {
      item = this.lLookAhead.shift();
      debug("return from Getter.get() with lookahead:", item);
      return item;
    }
    if (this.atEOF) {
      debug("return undef from Getter.get() - at EOF");
      return undef;
    }
    ({value, done} = this.iterator.next());
    if (done) {
      this.atEOF = true;
      debug("return undef from Getter.get() - done == true");
      return undef;
    }
    debug("return from Getter.get()", value);
    return value;
  }

  // ..........................................................
  unget(value) {
    debug("enter Getter.unget()", value);
    assert(value != null, "unget(): value must be defined");
    this.lLookAhead.unshift(value);
    debug("return from Getter.unget()");
  }

  // ..........................................................
  peek() {
    var done, value;
    debug('enter Getter.peek():');
    if (this.hasLookAhead()) {
      value = this.lookahead();
      debug('lLookAhead', this.lLookAhead);
      debug("return lookahead from Getter.peek()", value);
      return value;
    }
    if (this.atEOF) {
      debug("return undef from Getter.peek() - at EOF");
      return undef;
    }
    debug("no lookahead");
    ({value, done} = this.iterator.next());
    debug("from next()", {value, done});
    if (done) {
      debug('lLookAhead', this.lLookAhead);
      debug("return undef from Getter.peek()");
      return undef;
    }
    this.unget(value);
    debug('lLookAhead', this.lLookAhead);
    debug('return from Getter.peek()', value);
    return value;
  }

  // ..........................................................
  skip() {
    debug('enter Getter.skip():');
    if (this.hasLookAhead()) {
      this.lLookAhead.shift();
      debug("return from Getter.skip(): clear lookahead");
      return;
    }
    this.iterator.next();
    debug('return from Getter.skip()');
  }

  // ..........................................................
  eof() {
    var done, value;
    debug("enter Getter.eof()");
    if (this.hasLookAhead()) {
      debug("return false from Getter.eof() - lookahead exists");
      return false;
    }
    if (this.atEOF) {
      debug("return true from Getter.eof() - at EOF");
      return true;
    }
    ({value, done} = this.iterator.next());
    debug("from next()", {value, done});
    if (done) {
      debug("return true from Getter.eof()");
      return true;
    }
    this.unget(value);
    debug("return false from Getter.eof()");
    return false;
  }

};
