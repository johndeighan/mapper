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
    this.hConsts = {}; // support variable replacement
    
    // --- support peek(), etc.
    //     items are {item, uobj}
    this.lCache = [];
  }

  // ..........................................................
  setConst(name, value) {
    assert((name === 'LINE') || (this.hConsts[name] === undef), `cannot set constant ${name} twice`);
    this.hConsts[name] = value;
  }

  // ..........................................................
  getConst(name) {
    return this.hConsts[name];
  }

  // ..........................................................
  //    Cache Management
  // ..........................................................
  addToCache(item, uobj = undef) {
    this.lCache.unshift({item, uobj});
  }

  // ..........................................................
  getFromCache() {
    var h;
    assert(nonEmpty(this.lCache), "empty cache");
    h = this.lCache.shift();
    if (h.uobj) {
      return h.uobj;
    } else {
      return this.mapItem(h.item);
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
    var item, uobj;
    debug("enter get()");
    // --- return anything in @lCache
    if (nonEmpty(this.lCache)) {
      uobj = this.getFromCache();
      debug("return from get() - cached uobj", uobj);
      return uobj;
    }
    debug("no lookahead");
    item = this.fetch();
    debug("fetch() returned", item);
    if (item === undef) {
      debug("return undef from get() - at EOF");
      return undef;
    }
    uobj = this.mapItem(item);
    debug("mapItem() returned", uobj);
    if (uobj === undef) {
      uobj = this.get(); // recursive call
    }
    debug("return from get()", uobj);
    return uobj;
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
    var h, uobj, value;
    debug('enter Getter.peek()');
    // --- Any item in lCache that has uobj == undef has not
    //     been mapped. lCache may contain such items, but if
    //     they map to undef, they should be skipped
    while (nonEmpty(this.lCache)) {
      h = this.lCache[0];
      if (defined(h.uobj)) {
        debug("return cached item from Getter.peek()", h.uobj);
        return h.uobj;
      } else {
        h.uobj = this.mapItem(h.item);
        if (defined(h.uobj)) {
          debug("return cached item from Getter.peek()", h.uobj);
          return h.uobj;
        } else {
          this.lCache.shift(); // and continue loop
        }
      }
    }
    debug("no lookahead");
    value = this.fetch();
    if (value === undef) {
      debug("return undef from Getter.peek() - at EOF");
      return undef;
    }
    debug("fetch() returned", value);
    // --- @lCache is currently empty
    uobj = this.mapItem(value);
    debug("from mapItem()", uobj);
    // --- @lCache might be non-empty now!!!

    // --- if mapItem() returns undef, skip that item
    if (uobj === undef) {
      debug("mapItem() returned undef - recursive call");
      uobj = this.peek(); // recursive call
      debug("return from Getter.peek()", uobj);
      return uobj;
    }
    debug("set lookahead", value, uobj);
    this.addToCache(value, uobj);
    debug("return from Getter.peek()", uobj);
    return uobj;
  }

  // ..........................................................
  // return of undef doesn't mean EOF, it means skip this item
  mapItem(item) {
    var hInfo, newitem, type, uobj;
    debug("enter mapItem()", item);
    [type, hInfo] = this.getItemType(item);
    if (defined(type)) {
      debug(`item type is ${type}`);
      assert(isString(type) && nonEmpty(type), `bad type: ${OL(type)}`);
      debug("call handleItemType()");
      uobj = this.handleItemType(type, item, hInfo);
      debug("from handleItemType()", uobj);
    } else {
      debug("no special type");
      if (isString(item) && (item !== '__END__')) {
        newitem = this.replaceConsts(item, this.hConsts);
        if (newitem !== item) {
          debug(`=> '${newitem}'`);
          item = newitem;
        }
      }
      debug("call map()");
      uobj = this.map(item);
      debug("from map()", uobj);
    }
    debug("return from mapItem()", uobj);
    return uobj;
  }

  // ..........................................................
  replaceConsts(line, hVars = {}) {
    var replacerFunc;
    assert(isHash(hVars), "hVars is not a hash");
    replacerFunc = (match, prefix, name) => {
      var value;
      if (prefix) {
        return process.env[name];
      } else {
        value = hVars[name];
        if (defined(value)) {
          if (isString(value)) {
            return value;
          } else {
            return JSON.stringify(value);
          }
        } else {
          return `__${name}__`;
        }
      }
    };
    return line.replace(/__(env\.)?([A-Za-z_][A-Za-z0-9_]*)__/g, replacerFunc);
  }

  // ..........................................................
  getItemType(item) {
    return [
      // --- return [<name of item type>, <additional info>]
      undef,
      undef // default: no special item types
    ];
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
  map(item) {
    debug("enter Getter.map() - identity mapping", item);
    assert(defined(item), "item is undef");
    // --- by default, identity mapping
    debug("return from Getter.map()", item);
    return item;
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
    // --- NOTE: @get will skip items that are mapped to undef
    //           and only returns undef when the input is exhausted
    while (defined(item = this.get())) {
      yield item;
    }
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
