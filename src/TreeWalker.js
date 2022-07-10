// Generated by CoffeeScript 2.7.0
  // TreeWalker.coffee
import {
  assert,
  undef,
  pass,
  croak,
  defined,
  OL,
  rtrim,
  words,
  isString,
  isNumber,
  isEmpty,
  nonEmpty,
  isArray,
  isHash,
  isInteger
} from '@jdeighan/coffee-utils';

import {
  arrayToBlock
} from '@jdeighan/coffee-utils/block';

import {
  LOG,
  DEBUG
} from '@jdeighan/coffee-utils/log';

import {
  splitLine,
  indentLevel,
  indented,
  undented
} from '@jdeighan/coffee-utils/indent';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  Mapper
} from '@jdeighan/mapper';

import {
  lineToParts,
  mapHereDoc
} from '@jdeighan/mapper/heredoc';

// ===========================================================================
//   class TreeWalker
//      - map() returns mapped item or undef
//      - bundle() returns {item, level}
//   to use, override:
//      mapStr(str) - returns user object, default returns str
//      handleCmd()
//      beginWalk() -
//      visit(uobj, hUser, level, lStack) -
//      endVisit(uobj, hUser, level, lStack) -
//      endWalk() -
export var TreeWalker = class TreeWalker extends Mapper {
  constructor(source = undef, collection = undef, hOptions = {}) {
    super(source, collection, hOptions);
    this.srcLevel = 0;
    this.lMinuses = []; // used to adjust level in #ifdef and #ifndef
  }

  
    // ..........................................................
  // --- Should always return either:
  //        undef
  //        uobj - mapped object
  // --- Will only receive non-special lines
  map(item) {
    var hOptions, lExtLines, newStr, newstr, str;
    debug("enter map()", item);
    // --- a TreeWalker makes no sense unless items are strings
    assert(isString(item), `non-string: ${OL(item)}`);
    [this.srcLevel, str] = splitLine(item);
    debug(`split: level = ${OL(this.srcLevel)}, str = ${OL(str)}`);
    assert(nonEmpty(str), "empty string should be special");
    // --- check for extension lines, stop on blank line if found
    debug("check for extension lines");
    hOptions = {
      stopOn: ''
    };
    lExtLines = this.fetchLinesAtLevel(this.srcLevel + 2, hOptions);
    assert(isArray(lExtLines), "lExtLines not an array");
    debug(`${lExtLines.length} extension lines`);
    if (isEmpty(lExtLines)) {
      debug("no extension lines");
    } else {
      newstr = this.joinExtensionLines(str, lExtLines);
      if (newstr !== str) {
        str = newstr;
        debug(`=> ${OL(str)}`);
      }
    }
    // --- handle HEREDOCs
    debug("check for HEREDOC");
    if (str.indexOf('<<<') >= 0) {
      newStr = this.handleHereDocsInLine(str);
      if (newStr !== str) {
        str = newStr;
        debug(`=> ${OL(str)}`);
      }
    } else {
      debug("no HEREDOCs");
    }
    // --- NOTE: mapStr() may return undef, meaning to ignore
    item = this.mapStr(str, this.srcLevel);
    debug("return from map()", item);
    return item;
  }

  // ..........................................................
  // --- designed to override
  mapStr(str, srcLevel) {
    return str;
  }

  // ..........................................................
  bundle(item) {
    return {
      item,
      level: this.realLevel()
    };
  }

  // ..........................................................
  joinExtensionLines(line, lExtLines) {
    var contLine, j, len;
// --- There might be empty lines in lExtLines
//     but we'll skip them here
    for (j = 0, len = lExtLines.length; j < len; j++) {
      contLine = lExtLines[j];
      if (nonEmpty(contLine)) {
        line += ' ' + contLine.trim();
      }
    }
    return line;
  }

  // ..........................................................
  handleHereDocsInLine(line) {
    var block, expr, hOptions, j, lNewParts, lParts, len, part, result, str;
    // --- Indentation has been removed from line
    // --- Find each '<<<' and replace with result of mapHereDoc()
    debug("enter handleHereDocsInLine()", line);
    assert(isString(line), "not a string");
    lParts = lineToParts(line);
    debug('lParts', lParts);
    lNewParts = []; // to be joined to form new line
    for (j = 0, len = lParts.length; j < len; j++) {
      part = lParts[j];
      if (part === '<<<') {
        debug(`get HEREDOC lines at level ${this.srcLevel + 1}`);
        hOptions = {
          stopOn: '',
          discard: true // discard the terminating empty line
        };
        // --- block will be undented
        block = this.fetchBlockAtLevel(this.srcLevel + 1, hOptions);
        debug('block', block);
        expr = mapHereDoc(block);
        assert(defined(expr), "mapHereDoc returned undef");
        debug('mapped block', expr);
        str = this.handleHereDoc(expr, block);
        assert(defined(str), "handleHereDoc returned undef");
        lNewParts.push(str);
      } else {
        lNewParts.push(part); // keep as is
      }
    }
    result = lNewParts.join('');
    debug("return from handleHereDocsInLine", result);
    return result;
  }

  // ..........................................................
  handleHereDoc(cieloExpr, block) {
    return cieloExpr;
  }

  // ..........................................................
  extSep(str, nextStr) {
    return ' ';
  }

  // ..........................................................
  isEmptyHereDocLine(str) {
    return str === '.';
  }

  // ..........................................................
  // --- We define commands 'ifdef' and 'ifndef'
  handleCmd(cmd, argstr, prefix, h) {
    var isEnv, item, keep, lSkipLines, name, ok, value;
    // --- h has keys 'cmd','argstr' and 'prefix'
    //     but may contain additional keys
    debug("enter TreeWalker.handleCmd()", h);
    this.srcLevel = indentLevel(prefix);
    debug(`srcLevel = ${this.srcLevel}`);
    // --- Handle our commands, returning if found
    switch (cmd) {
      case 'ifdef':
      case 'ifndef':
        [name, value, isEnv] = this.splitDef(argstr);
        assert(defined(name), `Invalid ${cmd}, argstr=${OL(argstr)}`);
        ok = this.isDefined(name, value, isEnv);
        debug(`ok = ${OL(ok)}`);
        keep = cmd === 'ifdef' ? ok : !ok;
        debug(`keep = ${OL(keep)}`);
        if (keep) {
          this.lMinuses.push(this.srcLevel);
        } else {
          lSkipLines = this.fetchLinesAtLevel(this.srcLevel + 1);
          debug(`Skip ${lSkipLines.length} lines`);
        }
        debug("return undef from TreeWalker.handleCmd()");
        return undef;
    }
    debug("call super");
    item = super.handleCmd(cmd, argstr, prefix, h);
    debug("return from TreeWalker.handleCmd()", item);
    return item;
  }

  // ..........................................................
  realLevel() {
    var adjustment, i, j, lNewMinuses, len, ref;
    lNewMinuses = [];
    adjustment = 0;
    ref = this.lMinuses;
    for (j = 0, len = ref.length; j < len; j++) {
      i = ref[j];
      if (this.srcLevel > i) {
        adjustment += 1;
        lNewMinuses.push(i);
      }
    }
    this.lMinuses = lNewMinuses;
    return this.srcLevel - adjustment;
  }

  // ..........................................................
  splitDef(argstr) {
    var _, env, isEnv, lMatches, name, value;
    lMatches = argstr.match(/^(env\.)?([A-Za-z_][A-Za-z0-9_]*)\s*(.*)$/);
    if (lMatches) {
      [_, env, name, value] = lMatches;
      isEnv = nonEmpty(env) ? true : false;
      if (isEmpty(value)) {
        value = undef;
      }
      return [name, value, isEnv];
    } else {
      return [undef, undef, undef];
    }
  }

  // ..........................................................
  fetchLinesAtLevel(atLevel, hOptions = {}) {
    var discard, item, lLines, stopOn;
    // --- Does NOT remove any indentation
    stopOn = hOptions.stopOn;
    if (defined(stopOn)) {
      assert(isString(stopOn), `stopOn is ${OL(stopOn)}`);
      discard = hOptions.discard || false;
    }
    debug("enter TreeWalker.fetchLinesAtLevel()", atLevel, stopOn);
    assert(atLevel > 0, `atLevel is ${atLevel}`);
    lLines = [];
    while (defined(item = this.fetch()) && debug(`item = ${OL(item)}`) && isString(item) && ((stopOn === undef) || (item !== stopOn)) && (isEmpty(item) || (indentLevel(item) >= atLevel))) {
      debug(`push ${OL(item)}`);
      lLines.push(item);
    }
    // --- Cases:                            unfetch?
    //        1. item is undef                 NO
    //        2. item not a string             YES
    //        3. item == stopOn (& defined)    NO
    //        4. item nonEmpty and undented    YES
    if (isString(item) && !discard) {
      debug("do unfetch");
      this.unfetch(item);
    }
    debug("return from TreeWalker.fetchLinesAtLevel()", lLines);
    return lLines;
  }

  // ..........................................................
  fetchBlockAtLevel(atLevel, hOptions = {}) {
    var lLines, result;
    debug("enter TreeWalker.fetchBlockAtLevel()", atLevel, hOptions);
    lLines = this.fetchLinesAtLevel(atLevel, hOptions);
    debug('lLines', lLines);
    lLines = undented(lLines, atLevel);
    debug("undented lLines", lLines);
    result = arrayToBlock(lLines);
    debug("return from TreeWalker.fetchBlockAtLevel()", result);
    return result;
  }

  // ..........................................................
  // --- override these for tree walking
  beginWalk() {
    return undef;
  }

  // ..........................................................
  visit(item, hUser, level, lStack) {
    var result;
    debug("enter visit()", item, hUser, level);
    result = indented(item, level);
    debug("return from visit()", result);
    return result;
  }

  // ..........................................................
  endVisit(item, hUser, level, lStack) {
    return undef;
  }

  // ..........................................................
  endWalk() {
    return undef;
  }

  // ..........................................................
  // ..........................................................
  isDefined(name, value, isEnv) {
    if (isEnv) {
      if (defined(value)) {
        return process.env[name] === value;
      } else {
        return defined(process.env[name]);
      }
    } else {
      if (defined(value)) {
        return this.getConst(name) === value;
      } else {
        return defined(this.getConst(name));
      }
    }
    return true;
  }

  // ..........................................................
  whichCmd(uobj) {
    if (isHash(uobj) && uobj.hasOwnProperty('cmd')) {
      return uobj.cmd;
    }
    return undef;
  }

  // ..........................................................
  checkUserObj(uobj) {
    var item, level;
    assert(defined(uobj), "user object is undef");
    assert(isHash(uobj, words('item level')), `user object is ${OL(uobj)}`);
    ({item, level} = uobj);
    assert(defined(item), "item is undef");
    assert(isInteger(level), `level is ${OL(level)}`);
    assert(level >= 0, `level is ${OL(level)}`);
    return uobj;
  }

  // ..........................................................
  addText(text) {
    debug("enter addText()", text);
    if (defined(text)) {
      if (isArray(text)) {
        debug("text is an array");
        this.lLines.push(...text);
      } else {
        this.lLines.push(text);
      }
    }
    debug("return from addText()");
  }

  // ..........................................................
  walk() {
    var _, hUser, lStack, level, node, ref, result, text, uobj;
    debug("enter walk()");
    // --- lStack is stack of node = {
    //        uobj: {item, level}
    //        hUser: {}
    //        }
    this.lLines = []; // --- resulting lines
    lStack = [];
    debug("begin walk");
    text = this.beginWalk();
    this.addText(text);
    debug("getting uobj's");
    ref = this.allMapped();
    for (uobj of ref) {
      ({_, level} = this.checkUserObj(uobj));
      while (lStack.length > level) {
        node = lStack.pop();
        this.endVisitNode(node, lStack);
      }
      // --- Create a user hash that the user can add to/modify
      //     and will see again at endVisit
      hUser = {};
      node = {uobj, hUser};
      this.visitNode(node, lStack);
      lStack.push(node);
    }
    while (lStack.length > 0) {
      node = lStack.pop();
      this.endVisitNode(node, lStack);
    }
    text = this.endWalk();
    this.addText(text);
    result = arrayToBlock(this.lLines);
    debug("return from walk()", result);
    return result;
  }

  // ..........................................................
  visitNode(node, lStack) {
    var hUser, item, level, text, uobj;
    assert(isHash(node), `node is ${OL(node)}`);
    ({uobj, hUser} = node);
    ({item, level} = this.checkUserObj(uobj));
    text = this.visit(item, hUser, level, lStack);
    this.addText(text);
  }

  // ..........................................................
  endVisitNode(node, lStack) {
    var hUser, item, level, text, uobj;
    assert(isHash(node), `node is ${OL(node)}`);
    ({uobj, hUser} = node);
    assert(isHash(hUser), `hUser is ${OL(hUser)}`);
    ({item, level} = this.checkUserObj(uobj));
    text = this.endVisit(item, hUser, level, lStack);
    this.addText(text);
  }

  // ..........................................................
  getBlock() {
    var block, result;
    debug("enter getBlock()");
    block = this.walk();
    debug('block', block);
    result = this.finalizeBlock(block);
    debug("return from getBlock()", result);
    return result;
  }

};

// ---------------------------------------------------------------------------
export var TraceWalker = class TraceWalker extends TreeWalker {
  // ..........................................................
  //     builds a trace of the tree
  //        which is returned by endWalk()
  beginWalk() {
    this.lTrace = ["BEGIN WALK"]; // an array of strings
  }

  // ..........................................................
  visit(item, hUser, level, lStack) {
    this.lTrace.push(`VISIT ${level} ${OL(item)}`);
  }

  // ..........................................................
  endVisit(item, hUser, level, lStack) {
    this.lTrace.push(`END VISIT ${level} ${OL(item)}`);
  }

  // ..........................................................
  endWalk() {
    var block;
    this.lTrace.push("END WALK");
    block = arrayToBlock(this.lTrace);
    this.lTrace = undef;
    return block;
  }

};

// ---------------------------------------------------------------------------
