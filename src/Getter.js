// Generated by CoffeeScript 2.7.0
  // Getter.coffee
import {
  assert,
  undef,
  pass,
  croak,
  OL,
  rtrim,
  defined,
  notdefined,
  escapeStr,
  isString,
  isHash,
  isArray,
  replaceVars,
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

import {
  Fetcher
} from '@jdeighan/mapper/fetcher';

// ---------------------------------------------------------------------------
//   class Getter
//      - get(), peek(), eof(), skip() for mapped data
export var Getter = class Getter extends Fetcher {
  constructor(source = undef, collection = undef, hOptions = {}) {
    super(source, collection, hOptions);
    this.hVars = {}; // support variable replacement
    
    // --- support peek(), etc.
    //     items are {line, mapped, isMapped}
    this.lCache = []; // --- support peek()
  }

  
    // ..........................................................
  setVar(name, value) {
    this.hVars[name] = value;
  }

  // ..........................................................
  //    Cache Management
  // ..........................................................
  addToCache(line, mapped = undef, isMapped = true) {
    this.lCache.unshift({line, mapped, isMapped});
  }

  // ..........................................................
  getFromCache() {
    var h;
    assert(nonEmpty(this.lCache), "getFromCache() called on empty cache");
    h = this.lCache.shift();
    if (h.isMapped) {
      return h.mapped;
    } else {
      return this.mapItem(h.line);
    }
  }

  // ..........................................................
  fetchFromCache() {
    var h;
    assert(nonEmpty(this.lCache), "fetchFromCache() called on empty cache");
    h = this.lCache.shift();
    return h.unmapped;
  }

  // ..........................................................
  //        We override fetch(), unfetch()
  // ..........................................................
  fetch() {
    if (nonEmpty(this.lCache)) {
      return this.fetchFromCache();
    }
    return super.fetch();
  }

  // ..........................................................
  unfetch(line) {
    if (isEmpty(this.lCache)) {
      return super.unfetch(line);
    }
    this.addToCache(line, undef, false);
  }

  // ..........................................................
  //        Mapped Data
  // ..........................................................
  get() {
    var item, result, value;
    debug("enter Getter.get()");
    // --- return anything in @lCache
    if (nonEmpty(this.lCache)) {
      value = this.getFromCache();
      debug("return from Getter.get() - mapped lookahead", value);
      return value;
    }
    debug("no lookahead");
    item = this.fetch();
    debug("fetch() returned", item);
    if (item === undef) {
      debug("return undef from Getter.get() - at EOF");
      return undef;
    }
    result = this.mapItem(item);
    debug("mapItem() returned", result);
    if (result === undef) {
      result = this.get(); // recursive call
    }
    debug("return from Getter.get()", result);
    return result;
  }

  // ..........................................................
  skip() {
    debug('enter Getter.skip():');
    this.get();
    debug('return from Getter.skip()');
  }

  // ..........................................................
  eof() {
    var value;
    debug("enter Getter.eof()");
    if (nonEmpty(this.lCache)) {
      debug("return false from Getter.eof() - cache not empty");
      return false;
    }
    value = this.fetch();
    if (value === undef) {
      debug("return true from Getter.eof()");
      return true;
    } else {
      this.unfetch(value);
      debug("return false from Getter.eof()");
      return false;
    }
  }

  // ..........................................................
  peek() {
    var h, result, value;
    debug('enter Getter.peek()');
    if (nonEmpty(this.lCache)) {
      h = this.lCache[0];
      if (!h.isMapped) {
        h.mapped = this.mapItem(h.line);
        h.isMapped = true;
      }
      debug("return lookahead token from Getter.peek()", h.mapped);
      return h.mapped;
    }
    debug("no lookahead");
    value = this.fetch();
    if (value === undef) {
      debug("return undef from Getter.peek() - at EOF");
      return undef;
    }
    debug("fetch() returned", value);
    // --- @lCache is currently empty
    result = this.mapItem(value);
    debug("from mapItem()", result);
    // --- @lCache might be non-empty now!!!

    // --- if mapItem() returns undef, skip that item
    if (result === undef) {
      debug("mapItem() returned undef - recursive call");
      result = this.peek(); // recursive call
      debug("return from Getter.peek()", result);
      return result;
    }
    debug("set lookahead", result);
    this.addToCache(value, result, true);
    debug("return from Getter.peek()", result);
    return result;
  }

  // ..........................................................
  // return of undef doesn't mean EOF, it means skip this item
  mapItem(item) {
    var hInfo, newitem, result, type;
    debug("enter Getter.mapItem()", item);
    result = this.getItemType(item);
    if (defined(result)) {
      [type, hInfo] = result;
      debug(`item type is ${type}`);
      assert(isString(type) && nonEmpty(type), `bad type: ${OL(type)}`);
      debug("call handleItemType()");
      result = this.handleItemType(type, item, hInfo);
      debug("from handleItemType()", result);
    } else {
      if (isString(item) && (item !== '__END__')) {
        debug("replace vars");
        newitem = replaceVars(item, this.hVars);
        if (newitem !== item) {
          debug(`=> '${newitem}'`);
        }
        item = newitem;
      }
      debug("call map()");
      result = this.map(item);
      debug("from map()", result);
    }
    debug("return from Getter.mapItem()", result);
    return result;
  }

  // ..........................................................
  getItemType(item) {
    // --- return [<name of item type>, <additional info>]
    return undef; // default: not special item types
  }

  
    // ..........................................................
  handleItemType(type, item, hInfo) {
    return undef; // default - ignore any special item types
  }

  
    // ..........................................................
  // --- designed to override
  //     override may use fetch(), unfetch(), fetchBlock(), etc.
  //     should return undef to ignore line
  //     technically, line does not have to be a string,
  //        but it usually is
  map(line) {
    debug("enter Getter.map() - identity mapping", line);
    assert(defined(line), "line is undef");
    // --- by default, identity mapping
    debug("return from Getter.map()", line);
    return line;
  }

  // ..........................................................
  // --- override to map back to a string, default returns arg
  //     used in getBlock()
  unmap(item) {
    return item;
  }

  // ..........................................................
  // --- a generator
  * allMapped() {
    var item;
    debug("enter Getter.allMapped()");
    while (defined(item = this.get())) {
      debug("GOT", item);
      yield item;
    }
    debug("GOT", item);
    debug("return from Getter.allMapped()");
  }

  // ..........................................................
  getAll() {
    var item, lItems, ref;
    debug("enter Getter.getAll()");
    lItems = [];
    ref = this.allMapped();
    for (item of ref) {
      lItems.push(item);
    }
    debug("return from Getter.getAll()", lItems);
    return lItems;
  }

  // ..........................................................
  getUntil(end) {
    var item, lItems;
    debug("enter Getter.getUntil()");
    lItems = [];
    while (defined(item = this.get()) && (item !== end)) {
      lItems.push(item);
    }
    debug("return from Getter.getUntil()", lItems);
    return lItems;
  }

  // ..........................................................
  getBlock() {
    var block, endStr, item, lStrings, ref;
    debug("enter Getter.getBlock()");
    lStrings = [];
    ref = this.allMapped();
    for (item of ref) {
      debug("MAPPED", item);
      item = this.unmap(item);
      assert(isString(item), "mapped item not a string");
      lStrings.push(item);
    }
    debug('lStrings', lStrings);
    endStr = this.endBlock();
    if (defined(endStr)) {
      debug('endStr', endStr);
      lStrings.push(endStr);
    }
    block = arrayToBlock(lStrings);
    debug("return from Getter.getBlock()", block);
    return block;
  }

  // ..........................................................
  endBlock() {
    return undef;
  }

};
