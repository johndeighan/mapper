// Generated by CoffeeScript 2.6.1
// Getter.coffee
import assert from 'assert';

import {
  undef,
  pass,
  croak
} from '@jdeighan/coffee-utils';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

// ---------------------------------------------------------------------------
//   class Getter - get(), unget(), peek(), eof()
//   TODO: Currently works with arrays - make it work with any iterable!
export var Getter = class Getter {
  constructor(lItems) {
    this.lItems = lItems;
    this.lookahead = undef;
    this.pos = 0;
    this.len = this.lItems.length;
    debug("Construct a Getter");
  }

  get() {
    var item, saved;
    debug("enter get()");
    if (this.lookahead != null) {
      saved = this.lookahead;
      this.lookahead = undef;
      debug("return from get() with lookahead token:", saved);
      return saved;
    }
    if (this.pos === this.len) {
      return undef;
    }
    item = this.lItems[this.pos];
    this.pos += 1;
    debug("return from get() with:", item);
    return item;
  }

  unget(item) {
    debug(`enter unget(${item})`);
    if (this.lookahead != null) {
      debug("return FAILURE from unget() - lookahead exists");
      croak("Getter.unget(): lookahead exists");
    }
    this.lookahead = item;
    debug("return from unget()");
  }

  peek() {
    var item;
    debug('enter peek():');
    if (this.lookahead != null) {
      debug("return lookahead token from peek()", this.lookahead);
      return this.lookahead;
    }
    item = this.get();
    if (item == null) {
      return undef;
    }
    this.unget(item);
    debug('return from peek() with:', item);
    return item;
  }

  skip() {
    var item;
    debug('enter skip():');
    if (this.lookahead != null) {
      this.lookahead = undef;
      debug("return from skip(): clear lookahead token");
      return;
    }
    item = this.get();
    debug('return from skip()');
  }

  eof() {
    var atEnd;
    debug("enter eof()");
    atEnd = (this.pos === this.len) && (this.lookahead == null);
    debug(`return ${atEnd} from eof()`);
    return atEnd;
  }

};
