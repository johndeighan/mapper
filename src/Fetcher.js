// Generated by CoffeeScript 2.7.0
// Fetcher.coffee
import fs from 'fs';

import {
  assert,
  error,
  croak
} from '@jdeighan/unit-tester/utils';

import {
  undef,
  pass,
  OL,
  rtrim,
  defined,
  notdefined,
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
  splitPrefix,
  indentLevel,
  undented
} from '@jdeighan/coffee-utils/indent';

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

import {
  Node
} from '@jdeighan/mapper/node';

// ---------------------------------------------------------------------------
//   class Fetcher
//      - sets @hSourceInfo
//      - fetch(), unfetch()
//      - removes trailing WS from strings
//      - stops at __END__
//      - all() - generator
//      - fetchAll(), fetchBlock(), fetchUntil()
export var Fetcher = class Fetcher {
  constructor(source = undef, collection = undef, addLevel = 0) {
    var content;
    this.source = source;
    this.addLevel = addLevel;
    debug("enter Fetcher()", this.source, collection, this.addLevel);
    if (this.source) {
      this.hSourceInfo = parseSource(this.source);
      debug('hSourceInfo', this.hSourceInfo);
      assert(this.hSourceInfo.filename, "parseSource returned no filename");
    } else {
      this.hSourceInfo = {
        filename: '<unknown>'
      };
    }
    this.altInput = undef;
    this.lineNum = 0;
    this.oneIndent = undef; // set from 1st line with indentation
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
    var lParts;
    lParts = [];
    lParts.push(this.sourceStr());
    if (defined(this.altInput)) {
      lParts.push(this.altInput.sourceStr());
    }
    return lParts.join(' ');
  }

  // ..........................................................
  sourceStr() {
    return `${this.hSourceInfo.filename}/${this.lineNum}`;
  }

  // ..........................................................
  // --- returns hNode with keys:
  //        str
  //        level
  //        source
  //        lineNum
  fetch() {
    var _, done, fname, hNode, lMatches, level, line, prefix, str;
    debug(`enter Fetcher.fetch() from ${this.hSourceInfo.filename}`);
    if (defined(this.altInput)) {
      debug("has altInput");
      hNode = this.altInput.fetch();
      // --- NOTE: hNode.str will never be #include
      //           because altInput's fetch would handle it
      if (defined(hNode)) {
        debug("return from Fetcher.fetch() - alt", hNode);
        return hNode;
      }
      // --- alternate input is exhausted
      this.altInput = undef;
      debug("alt EOF");
    } else {
      debug("there is no altInput");
    }
    // --- return anything in lLookAhead,
    //     even if @forcedEOF is true
    if (this.lLookAhead.length > 0) {
      hNode = this.lLookAhead.shift();
      assert(defined(hNode), "undef in lLookAhead");
      assert(!hNode.str.match(/^\#include\b/), `got ${OL(hNode)} from lLookAhead`);
      // --- NOTE: hNode.str will never be #include
      //           because anything that came from lLookAhead
      //           was put there by unfetch() which doesn't
      //           allow #include
      this.incLineNum(1);
      debug("return from Fetcher.fetch() - lookahead", hNode);
      return hNode;
    }
    debug("no lookahead");
    if (this.forcedEOF) {
      debug("return from Fetcher.fetch() - forced EOF", undef);
      return undef;
    }
    debug("not at forced EOF");
    ({
      value: line,
      done
    } = this.iterator.next());
    debug("iterator returned", {line, done});
    if (done) {
      debug("return from Fetcher.fetch() - iterator DONE", undef);
      return undef;
    }
    assert(isString(line), `line is ${OL(line)}`);
    if (lMatches = line.match(/^(\s*)__END__$/)) {
      [_, prefix] = lMatches;
      assert(prefix === '', "__END__ should be at level 0");
      this.forceEOF();
      debug("return from Fetcher.fetch() - __END__", undef);
      return undef;
    }
    this.incLineNum(1);
    [prefix, str] = splitPrefix(line);
    // --- Ensure that @oneIndent is set, if possible
    //     set level
    if (prefix === '') {
      level = 0;
    } else if (defined(this.oneIndent)) {
      level = indentLevel(prefix, this.oneIndent);
    } else {
      if (lMatches = prefix.match(/^\t+$/)) {
        this.oneIndent = "\t";
        level = prefix.length;
      } else {
        this.oneIndent = prefix;
        level = 1;
      }
    }
    assert(defined(this.oneIndent) || (prefix === ''), `Bad prefix ${OL(prefix)}`);
    // --- check for #include
    if (lMatches = str.match(/^\#include\b\s*(.*)$/)) {
      [_, fname] = lMatches;
      debug(`#include ${fname}`);
      assert(nonEmpty(fname), "missing file name in #include");
      this.createAltInput(fname, level);
      hNode = this.fetch(); // recursive call
      debug("return from Fetcher.fetch()", hNode);
      return hNode;
    }
    hNode = new Node(str, level + this.addLevel, this.sourceInfoStr(), this.lineNum);
    debug("return from Fetcher.fetch()", hNode);
    return hNode;
  }

  // ..........................................................
  createAltInput(fname, level) {
    var dir, fullpath;
    debug("enter createAltInput()", fname, level);
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
    this.altInput = new Fetcher(fullpath, undef, level);
    debug("return from createAltInput()");
  }

  // ..........................................................
  unfetch(hNode) {
    var lMatches;
    debug("enter Fetcher.unfetch()", hNode);
    assert(hNode instanceof Node, `hNode is ${OL(hNode)}`);
    if (defined(this.altInput)) {
      debug("has alt input");
      this.altInput.unfetch(hNode);
      this.incLineNum(-1);
      debug("return from Fetcher.unfetch() - alt");
      return;
    }
    assert(defined(hNode), "hNode must be defined");
    lMatches = hNode.str.match(/^\#include\b/);
    assert(isEmpty(lMatches), "unfetch() of a #include");
    this.lLookAhead.unshift(hNode);
    this.incLineNum(-1);
    debug("return from Fetcher.unfetch()");
  }

  // ..........................................................
  // --- override to keep variable LINE updated
  incLineNum(inc = 1) {
    this.lineNum += inc;
  }

  // ..........................................................
  forceEOF() {
    debug("enter forceEOF()");
    this.forcedEOF = true;
    debug("return from forceEOF()");
  }

  // ..........................................................
  // --- GENERATOR
  * all() {
    var hNode;
    debug("enter Fetcher.all()");
    while (defined(hNode = this.fetch())) {
      debug("GOT", hNode);
      yield hNode;
    }
    debug("return from Fetcher.all()");
  }

  // ..........................................................
  // --- GENERATOR
  * allUntil(func, hOptions = undef) {
    var discardEndLine, hNode;
    // --- stop when func(hNode) returns true
    debug("enter Fetcher.allUntil()");
    assert(isFunction(func), "Arg 1 not a function");
    if (defined(hOptions)) {
      discardEndLine = hOptions.discardEndLine;
    } else {
      discardEndLine = true;
    }
    while (defined(hNode = this.fetch()) && !func(hNode)) {
      debug("GOT", hNode);
      yield hNode;
    }
    if (defined(hNode) && !discardEndLine) {
      this.unfetch(hNode);
    }
    debug("return from Fetcher.allUntil()");
  }

  // ..........................................................
  // --- fetch a list of Nodes
  fetchAll() {
    var lNodes;
    debug("enter Fetcher.fetchAll()");
    lNodes = Array.from(this.all());
    debug("return from Fetcher.fetchAll()", lNodes);
    return lNodes;
  }

  // ..........................................................
  fetchUntil(func, hOptions = undef) {
    var hNode, lNodes, ref;
    debug("enter Fetcher.fetchUntil()", func, hOptions);
    assert(isFunction(func), `not a function: ${OL(func)}`);
    lNodes = [];
    ref = this.allUntil(func, hOptions);
    for (hNode of ref) {
      lNodes.push(hNode);
    }
    debug("return from Fetcher.fetchUntil()", lNodes);
    return lNodes;
  }

  // ..........................................................
  // --- fetch a block
  fetchBlock() {
    var lNodes, result;
    debug("enter Fetcher.fetchBlock()");
    lNodes = Array.from(this.all());
    result = this.toBlock(lNodes);
    debug("return from Fetcher.fetchBlock()", result);
    return result;
  }

  // ..........................................................
  fetchBlockUntil(func, hOptions = undef) {
    var lNodes, result;
    debug("enter Fetcher.fetchBlockUntil()");
    lNodes = this.fetchUntil(func, hOptions);
    result = this.toBlock(lNodes);
    debug("return from Fetcher.fetchBlockUntil()", result);
    return result;
  }

  // ..........................................................
  toBlock(lNodes) {
    var hNode, i, lStrings, len;
    lStrings = [];
    for (i = 0, len = lNodes.length; i < len; i++) {
      hNode = lNodes[i];
      lStrings.push(hNode.getLine(this.oneIndent));
    }
    lStrings = undented(lStrings);
    return arrayToBlock(lStrings);
  }

};
