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
//      - map() returns mapped item (i.e. uobj) or undef
//   to use, override:
//      mapStr(str, srcLevel) - returns user object, default returns str
//      mapCmd(hLine)
//      beginWalk()
//      visit(hLine, hUser, lStack)
//      endVisit(hLine, hUser, lStack)
//      endWalk() -
export var TreeWalker = class TreeWalker extends Mapper {
  constructor(source = undef, collection = undef, hOptions = {}) {
    super(source, collection, hOptions);
    this.lMinuses = []; // used to adjust level in #ifdef and #ifndef
  }

  
    // ..........................................................
  // --- Should always return either:
  //        undef
  //        uobj - mapped object
  // --- Will only receive non-special lines
  //     1. add extension lines
  //     2. replace HEREDOCs
  //     3. call mapStr()
  map(hLine) {
    var lExtLines, level, line, newStr, prefix, srcLevel, str, uobj;
    // --- NOTE: We allow hLine.line to be a non-string
    //           But, in that case, to get tree functionality,
    //           the objects being iterated should have a level key
    //           If not, the level defaults to 0
    debug("enter TreeWalker.map()", hLine);
    if (this.adjustLevel(hLine)) {
      debug("hLine adjusted", hLine);
    }
    ({line, prefix, str, level, srcLevel} = hLine);
    if (!isString(line)) {
      // --- may return undef
      uobj = mapNonStr(line);
      debug("return from TreeWalker.map()", uobj);
      return uobj;
    }
    // --- from here on, line is a string
    assert(nonEmpty(str), "empty string should be special");
    // --- check for extension lines, stop on blank line if found
    debug("check for extension lines");
    lExtLines = this.fetchLinesAtLevel(srcLevel + 2, {
      stopOn: ''
    });
    assert(isArray(lExtLines), "lExtLines not an array");
    debug(`${lExtLines.length} extension lines`);
    if (isEmpty(lExtLines)) {
      debug("no extension lines");
    } else {
      this.joinExtensionLines(hLine, lExtLines);
      debug("with ext lines", hLine);
      ({line, prefix, str} = hLine);
    }
    // --- handle HEREDOCs
    debug("check for HEREDOC");
    if (str.indexOf('<<<') >= 0) {
      newStr = this.handleHereDocsInLine(str, srcLevel);
      if (newStr !== str) {
        str = newStr;
        debug(`=> ${OL(str)}`);
      }
    } else {
      debug("no HEREDOCs");
    }
    // --- NOTE: mapStr() may return undef, meaning to ignore
    //     We must pass srcLevel since mapStr() may use fetch()
    uobj = this.mapStr(str, srcLevel);
    debug("return from TreeWalker.map()", uobj);
    return uobj;
  }

  // ..........................................................
  // --- designed to override
  mapStr(str, srcLevel) {
    return str;
  }

  // ..........................................................
  // --- designed to override
  mapNonStr(item) {
    return item;
  }

  // ..........................................................
  // --- can override to change how lines are joined
  joinExtensionLines(hLine, lExtLines) {
    var hContLine, j, len;
// --- modifies keys line & str

    // --- There might be empty lines in lExtLines
//     but we'll skip them here
    for (j = 0, len = lExtLines.length; j < len; j++) {
      hContLine = lExtLines[j];
      if (nonEmpty(hContLine.str)) {
        hLine.line += ' ' + hContLine.str;
        hLine.str += ' ' + hContLine.str;
      }
    }
  }

  // ..........................................................
  handleHereDocsInLine(line, srcLevel) {
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
        debug(`get HEREDOC lines at level ${srcLevel + 1}`);
        hOptions = {
          stopOn: '',
          discard: true // discard the terminating empty line
        };
        // --- block will be undented
        block = this.fetchBlockAtLevel(srcLevel + 1, hOptions);
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
  handleHereDoc(expr, block) {
    return expr;
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
  mapComment(hLine) {
    var level, line, prefix, srcLevel;
    debug("enter TreeWalker.mapComment()", hLine);
    if (this.adjustLevel(hLine)) {
      debug("hLine adjusted", hLine);
    }
    ({line, prefix, level, srcLevel} = hLine);
    debug(`srcLevel = ${srcLevel}`);
    debug("return from TreeWalker.mapComment()", line);
    return line;
  }

  // ..........................................................
  // --- We define commands 'ifdef' and 'ifndef'
  mapCmd(hLine) {
    var argstr, cmd, isEnv, item, keep, lSkipLines, name, ok, prefix, srcLevel, value;
    debug("enter TreeWalker.mapCmd()", hLine);
    if (this.adjustLevel(hLine)) {
      debug("hLine adjusted", hLine);
    }
    ({cmd, argstr, prefix, srcLevel} = hLine);
    debug(`srcLevel = ${srcLevel}`);
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
          debug(`add ${srcLevel} to lMinuses`);
          this.lMinuses.push(srcLevel);
        } else {
          lSkipLines = this.fetchLinesAtLevel(srcLevel + 1);
          debug(`Skip ${lSkipLines.length} lines`);
        }
        debug("return undef from TreeWalker.mapCmd()");
        return undef;
    }
    debug("call super");
    item = super.mapCmd(hLine);
    debug("return from TreeWalker.mapCmd()", item);
    return item;
  }

  // ..........................................................
  adjustLevel(hLine) {
    var adjust, i, j, lNewMinuses, len, newLevel, ref, srcLevel;
    debug("enter adjustLevel()", hLine);
    if (defined(hLine.level)) {
      hLine.srcLevel = srcLevel = hLine.level;
      assert(isInteger(srcLevel), `level is ${OL(srcLevel)}`);
    } else {
      // --- if we're iterating non-strings, there won't be a level
      hLine.srcLevel = srcLevel = 0;
    }
    // --- Calculate the needed adjustment and new level
    lNewMinuses = [];
    adjust = 0;
    ref = this.lMinuses;
    for (j = 0, len = ref.length; j < len; j++) {
      i = ref[j];
      if (srcLevel > i) {
        adjust += 1;
        lNewMinuses.push(i);
      }
    }
    this.lMinuses = lNewMinuses;
    debug('lMinuses', this.lMinuses);
    if (adjust === 0) {
      debug("return false from adjustLevel()");
      return false;
    }
    assert(srcLevel >= adjust, `srcLevel=${srcLevel}, adjust=${adjust}`);
    newLevel = srcLevel - adjust;
    // --- Make adjustments to hLine
    hLine.level = newLevel;
    if (isString(hLine.line)) {
      hLine.line = undented(hLine.line, adjust);
      hLine.prefix = undented(hLine.prefix, adjust);
    }
    debug(`level adjusted ${srcLevel} => ${newLevel}`);
    debug("return true from adjustLevel()");
    return true;
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
    var discardStopLine, hLine, lLines, stopOn;
    // --- Does NOT remove any indentation
    //     Valid options:
    //        discard - discard ending line
    debug("enter TreeWalker.fetchLinesAtLevel()", atLevel, hOptions);
    assert(atLevel > 0, `atLevel is ${atLevel}`);
    discardStopLine = hOptions.discard || false;
    stopOn = hOptions.stopOn;
    if (defined(stopOn)) {
      assert(isString(stopOn), `stopOn is ${OL(stopOn)}`);
    }
    lLines = [];
    while (defined(hLine = this.fetch()) && debug('hLine', hLine) && isString(hLine.line) && ((stopOn === undef) || (hLine.line !== stopOn)) && (isEmpty(hLine.line) || (hLine.level >= atLevel))) {
      debug("add to lLines", hLine);
      lLines.push(hLine);
    }
    // --- Cases:                            unfetch?
    //        1. line is undef                 NO
    //        2. line not a string             YES
    //        3. line == stopOn (& defined)    NO
    //        4. line nonEmpty and undented    YES
    if (defined(hLine)) {
      if (discardStopLine && (hLine.line === stopOn)) {
        debug(`discard stop line ${OL(stopOn)}`);
      } else {
        debug("unfetch last line", hLine);
        this.unfetch(hLine);
      }
    }
    debug("return from TreeWalker.fetchLinesAtLevel()", lLines);
    return lLines;
  }

  // ..........................................................
  fetchBlockAtLevel(atLevel, hOptions = {}) {
    var hLine, lLines, lRawLines, lUndentedLines, result;
    debug("enter TreeWalker.fetchBlockAtLevel()", atLevel, hOptions);
    lLines = this.fetchLinesAtLevel(atLevel, hOptions);
    debug('lLines', lLines);
    lRawLines = (function() {
      var j, len, results;
      results = [];
      for (j = 0, len = lLines.length; j < len; j++) {
        hLine = lLines[j];
        results.push(hLine.line);
      }
      return results;
    })();
    debug('lRawLines', lRawLines);
    lUndentedLines = undented(lRawLines, atLevel);
    debug("undented lLines", lUndentedLines);
    result = arrayToBlock(lUndentedLines);
    debug("return from TreeWalker.fetchBlockAtLevel()", result);
    return result;
  }

  // ========================================================================
  // --- override these for tree walking
  beginWalk() {
    return undef;
  }

  // ..........................................................
  visit(hLine, hUser, lStack) {
    var level, result, uobj;
    debug("enter visit()", hLine, hUser, lStack);
    ({uobj, level} = hLine);
    assert(isString(uobj), "uobj not a string");
    result = indented(uobj, level);
    debug("return from visit()", result);
    return result;
  }

  // ..........................................................
  endVisit(hLine, hUser, lStack) {
    debug("enter endVisit()", hLine, hUser, lStack);
    debug("return undef from endVisit()");
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
  addText(text) {
    debug("enter addText()", text);
    assert(defined(text), "text is undef");
    if (isArray(text)) {
      debug("text is an array");
      this.lLines.push(...text);
    } else {
      this.lLines.push(text);
    }
    debug("return from addText()");
  }

  // ..........................................................
  walk(hOptions = {}) {
    var hLine, hLine2, hLine3, hUser, hUser2, hUser3, i, lStack, level, node, ref, result, text;
    // --- Valid options: logLines
    debug("enter walk()");
    // --- lStack is stack of node = {
    //        hLine: {line, type, level, uobj}
    //        hUser: {}
    //        }
    this.lLines = []; // --- resulting lines - added via @addText()
    lStack = [];
    debug("begin walk");
    if (defined(text = this.beginWalk())) {
      this.addText(text);
    }
    debug("getting lines");
    i = 0;
    ref = this.allMapped();
    for (hLine of ref) {
      if (hOptions.logLines) {
        LOG(`hLine[${i}]`, hLine);
      } else {
        debug("hLine", hLine);
      }
      i += 1;
      ({level} = hLine);
      while (lStack.length > level) {
        node = lStack.pop();
        debug("popped node", node);
        ({
          hLine: hLine2,
          hUser: hUser2
        } = node);
        assert(defined(hLine2), "hLine2 is undef");
        if (defined(text = this.endVisit(hLine2, hUser2, lStack))) {
          this.addText(text);
        }
      }
      // --- Create a user hash that the user can add to/modify
      //     and will see again at endVisit
      hUser = {};
      if (defined(text = this.visit(hLine, hUser, lStack))) {
        this.addText(text);
      }
      lStack.push({hLine, hUser});
    }
    while (lStack.length > 0) {
      node = lStack.pop();
      ({
        hLine: hLine3,
        hUser: hUser3
      } = node);
      assert(defined(hLine3), "hLine3 is undef");
      if (defined(text = this.endVisit(hLine3, hUser3, lStack))) {
        this.addText(text);
      }
    }
    if (defined(text = this.endWalk())) {
      this.addText(text);
    }
    result = arrayToBlock(this.lLines);
    debug("return from walk()", result);
    return result;
  }

  // ..........................................................
  getBlock(hOptions = {}) {
    var block, result;
    // --- Valid options: logLines
    debug("enter getBlock()");
    block = this.walk(hOptions);
    debug('block', block);
    result = this.finalizeBlock(block);
    debug("return from getBlock()", result);
    return result;
  }

};
