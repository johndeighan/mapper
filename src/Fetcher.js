// Generated by CoffeeScript 2.7.0
// Fetcher.coffee
import fs from 'fs';

import {
  assert,
  undef,
  pass,
  croak,
  OL,
  rtrim,
  defined,
  escapeStr,
  isString,
  isHash,
  isArray,
  isFunction,
  isIterable,
  isEmpty,
  nonEmpty
} from '@jdeighan/coffee-utils';

import {
  arrayToBlock,
  blockToArray
} from '@jdeighan/coffee-utils/block';

import {
  LOG,
  DEBUG
} from '@jdeighan/coffee-utils/log';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  parseSource,
  slurp,
  isSimpleFileName,
  isDir,
  pathTo
} from '@jdeighan/coffee-utils/fs';

// ---------------------------------------------------------------------------
//   class Fetcher
//      - sets @hSourceInfo
//      - fetch(), unfetch()
//      - removes trailing WS from strings
//      - stops at __END__
//      - valid options:
//           prefix - prepend this prefix when fetching
//      - all() - generator
//      - fetchAll(), fetchBlock(), fetchUntil()
export var Fetcher = class Fetcher {
  constructor(source = undef, collection = undef, hOptions = {}) {
    var content;
    this.source = source;
    debug(`enter Fetcher(${OL(this.source)})`, collection);
    if (this.source) {
      this.hSourceInfo = parseSource(this.source);
      debug('hSourceInfo', this.hSourceInfo);
      assert(this.hSourceInfo.filename, "parseSource returned no filename");
    } else {
      this.hSourceInfo = {
        filename: '<unknown>'
      };
    }
    // --- Add current line number to hSourceInfo
    this.hSourceInfo.lineNum = 0;
    if (hOptions.prefix != null) {
      this.hSourceInfo.prefix = hOptions.prefix;
    }
    if (collection === undef) {
      if (this.hSourceInfo.fullpath) {
        content = slurp(this.hSourceInfo.fullpath);
        debug('content', content);
        collection = blockToArray(content);
      } else {
        croak("no source or fullpath");
      }
    } else if (isString(collection)) {
      collection = blockToArray(collection);
      debug("collection becomes", collection);
    }
    // --- collection must be iterable
    assert(isIterable(collection), "collection not iterable");
    this.iterator = collection[Symbol.iterator]();
    this.lLookAhead = []; // --- support unfetch()
    this.forcedEOF = false;
    if (defined(hOptions.prefix)) {
      this.prefix = hOptions.prefix;
    } else {
      this.prefix = '';
    }
    debug('prefix', this.prefix);
    this.init();
    debug("return from Fetcher()");
  }

  // ..........................................................
  pathTo(fname) {
    // --- fname must be a simple file name
    // --- returns a relative path
    //     searches from @hSourceInfo.dir || process.cwd()
    //     searches downward
    assert(isSimpleFileName(fname), "fname must not be a path");
    return pathTo(fname, this.hSourceInfo.dir, {
      relative: true
    });
  }

  // ..........................................................
  init() {}

  // ..........................................................
  sourceInfoStr() {
    var h, lParts;
    lParts = [];
    h = this.hSourceInfo;
    lParts.push(this.sourceStr(h));
    while (defined(h.altInput)) {
      h = h.altInput.hSourceInfo;
      lParts.push(this.sourceStr(h));
    }
    return lParts.join(' ');
  }

  // ..........................................................
  sourceStr(h) {
    assert(isHash(h, ['filename', 'lineNum']), `h is ${OL(h)}`);
    return `${h.filename}/${h.lineNum}`;
  }

  // ..........................................................
  // --- returns a hash with keys:
  //        line
  fetch() {
    var _, done, fname, hItem, lMatches, prefix, value;
    debug(`enter Fetcher.fetch() from ${this.hSourceInfo.filename}`);
    if (defined(this.hSourceInfo.altInput)) {
      debug("has altInput");
      value = this.hSourceInfo.altInput.fetch();
      // --- NOTE: value will never be #include
      //           because altInput's fetch would handle it
      if (defined(value)) {
        debug("got alt value", value);
        debug("return from Fetcher.fetch() - alt", value);
        return value;
      }
      // --- alternate input is exhausted
      this.hSourceInfo.altInput = undef;
      debug("alt EOF");
    } else {
      debug("there is no altInput");
    }
    // --- return anything in lLookAhead,
    //     even if @forcedEOF is true
    if (this.lLookAhead.length > 0) {
      value = this.lLookAhead.shift();
      // --- NOTE: value will never be #include
      //           because anything that came from lLookAhead
      //           was put there by unfetch() which doesn't
      //           allow #include
      assert(defined(value), "undef in lLookAhead");
      this.incLineNum(1);
      debug("return from Fetcher.fetch() - lookahead", value);
      return value;
    }
    debug("no lookahead");
    if (this.forcedEOF) {
      debug("return undef from Fetcher.fetch() - forced EOF");
      return undef;
    }
    debug("not at EOF");
    ({value, done} = this.iterator.next());
    debug("iterator returned", {value, done});
    if (done) {
      debug("return undef from Fetcher.fetch() - iterator DONE");
      return undef;
    }
    if (value === '__END__') {
      this.forceEOF();
      debug("return undef from Fetcher.fetch() - __END__");
      return undef;
    }
    this.incLineNum(1);
    if (isString(value)) {
      value = rtrim(value); // remove trailing whitespace
      
      // --- check for #include
      if (lMatches = value.match(/(\s*)\#include\b\s*(.*)$/)) { // prefix
        [_, prefix, fname] = lMatches;
        debug(`#include ${fname} with prefix '${escapeStr(prefix)}'`);
        assert(nonEmpty(fname), "missing file name in #include");
        this.createAltInput(fname, prefix);
        value = this.fetch(); // recursive call
        debug("return from Fetcher.fetch()", value);
        return value;
      }
    }
    if (this.prefix.length > 0) {
      assert(isString(value), "prefix with non-string value");
      value = this.prefix + value;
    }
    hItem = {
      item: value,
      lineNum: this.hSourceInfo.lineNum,
      source: this.sourceInfoStr()
    };
    debug("return from Fetcher.fetch()", hItem);
    return hItem;
  }

  // ..........................................................
  createAltInput(fname, prefix = '') {
    var dir, fullpath;
    debug(`enter createAltInput('${fname}', '${escapeStr(prefix)}')`);
    // --- Make sure we have a simple file name
    assert(isString(fname), `not a string: ${OL(fname)}`);
    assert(isSimpleFileName(fname), `not a simple file name: ${OL(fname)}`);
    // --- Decide which directory to search for file
    dir = this.hSourceInfo.dir;
    if (dir) {
      assert(isDir(dir), `not a directory: ${OL(dir)}`);
    } else {
      dir = process.cwd(); // --- Use current directory
    }
    fullpath = pathTo(fname, dir);
    debug("fullpath", fullpath);
    if (fullpath === undef) {
      croak(`Can't find include file ${fname} in dir ${dir}`);
    }
    assert(fs.existsSync(fullpath), `${fullpath} does not exist`);
    this.hSourceInfo.altInput = new Fetcher(fullpath, undef, {prefix});
    debug("return from createAltInput()");
  }

  // ..........................................................
  unfetch(value) {
    var item, lMatches;
    debug("enter Fetcher.unfetch()", value);
    assert(defined(value), "value must be defined");
    ({item} = value);
    if (isString(item)) {
      lMatches = item.match(/^\s*\#include\b/);
      assert(isEmpty(lMatches), "unfetch() of a #include");
    }
    if (defined(this.hSourceInfo.altInput)) {
      debug("has alt input");
      this.hSourceInfo.altInput.unfetch(value);
      this.incLineNum(-1);
      debug("return from Fetcher.unfetch() - alt");
      return;
    }
    this.lLookAhead.unshift(value);
    this.incLineNum(-1);
    debug("return from Fetcher.unfetch()");
  }

  // ..........................................................
  // --- override to keep variable LINE updated
  incLineNum(inc = 1) {
    this.hSourceInfo.lineNum += inc;
  }

  // ..........................................................
  forceEOF() {
    debug("enter forceEOF()");
    this.forcedEOF = true;
    debug("return from forceEOF()");
  }

  // ..........................................................
  // --- a generator
  * all() {
    var item;
    debug("enter Fetcher.all()");
    while (defined(item = this.fetch())) {
      debug("GOT", item);
      yield item;
    }
    debug("GOT", item);
    debug("return from Fetcher.all()");
  }

  // ..........................................................
  fetchAll() {
    var item, lItems, ref;
    debug("enter Fetcher.fetchAll()");
    lItems = [];
    ref = this.all();
    for (item of ref) {
      lItems.push(item);
    }
    debug("return from Fetcher.fetchAll()", lItems);
    return lItems;
  }

  // ..........................................................
  fetchUntil(end) {
    var h, lItems;
    debug("enter Fetcher.fetchUntil()");
    lItems = [];
    while (defined(h = this.fetch()) && (h.item !== end)) {
      lItems.push(h);
    }
    debug("return from Fetcher.fetchUntil()", lItems);
    return lItems;
  }

  // ..........................................................
  fetchBlock() {
    var block, h, lStrings, ref, str;
    debug("enter Fetcher.fetchBlock()");
    lStrings = [];
    ref = this.all();
    for (h of ref) {
      str = h.item;
      assert(isString(str), `fetchBlock(): non-string ${OL(str)}`);
      lStrings.push(str);
    }
    debug('lStrings', lStrings);
    block = arrayToBlock(lStrings);
    debug("return from Fetcher.fetchBlock()", block);
    return block;
  }

};
