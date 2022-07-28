// Generated by CoffeeScript 2.7.0
  // TreeWalker.coffee
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
  rtrim,
  words,
  isString,
  isNumber,
  isFunction,
  isArray,
  isHash,
  isInteger,
  isEmpty,
  nonEmpty
} from '@jdeighan/coffee-utils';

import {
  arrayToBlock
} from '@jdeighan/coffee-utils/block';

import {
  log,
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
//      - mapNonSpecial() returns mapped item (i.e. uobj) or undef
//   to use, override:
//      map(hNode) - returns user object, def: returns hNode.str
//      mapCmd(hNode)
//      beginWalk()
//      visit(hNode, hUser, lStack)
//      endVisit(hNode, hUser, lStack)
//      endWalk() -
export var TreeWalker = class TreeWalker extends Mapper {
  constructor(source = undef, collection = undef, hOptions = {}) {
    super(source, collection, hOptions);
    this.hSpecialVisitTypes = {};
    this.registerVisitType('empty', this.visitEmptyLine, this.endVisitEmptyLine);
    this.registerVisitType('comment', this.visitComment, this.endVisitComment);
    this.registerVisitType('cmd', this.visitCmd, this.endVisitCmd);
    this.lMinuses = []; // used to adjust level in #ifdef and #ifndef
  }

  
    // ..........................................................
  registerVisitType(type, visiter, endVisiter) {
    this.hSpecialVisitTypes[type] = {visiter, endVisiter};
  }

  // ..........................................................
  mapNode(hNode) {
    var uobj;
    debug("enter TreeWalker.mapNode()", hNode);
    if (this.adjustLevel(hNode)) {
      debug("hNode.level adjusted", hNode);
    } else {
      debug("no adjustment");
    }
    uobj = super.mapNode(hNode);
    debug("return from TreeWalker.mapNode()", uobj);
    return uobj;
  }

  // ..........................................................
  // --- Should always return either:
  //        undef
  //        uobj - mapped object
  // --- Will only receive non-special lines
  //     1. add extension lines
  //     2. replace HEREDOCs
  //     3. call map()
  mapNonSpecial(hNode) {
    var lExtLines, level, newStr, srcLevel, str, uobj;
    debug("enter TreeWalker.mapNonSpecial()", hNode);
    assert(notdefined(hNode.type), `hNode is ${OL(hNode)}`);
    ({str, level, srcLevel} = hNode);
    // --- from here on, str is a non-empty string
    assert(nonEmpty(str), `hNode is ${OL(hNode)}`);
    assert(isInteger(srcLevel, {
      min: 0
    }), `hNode is ${OL(hNode)}`);
    // --- check for extension lines, stop on blank line if found
    debug("check for extension lines");
    lExtLines = this.fetchLinesAtLevel(srcLevel + 2, {
      stopOn: ''
    });
    assert(isArray(lExtLines), "lExtLines not an array");
    debug(`${lExtLines.length} extension lines`);
    if (!isEmpty(lExtLines)) {
      this.joinExtensionLines(hNode, lExtLines);
      debug("with ext lines", hNode);
      ({str} = hNode);
    }
    // --- handle HEREDOCs
    debug("check for HEREDOC");
    if (str.indexOf('<<<') >= 0) {
      newStr = this.handleHereDocsInLine(str, srcLevel);
      str = newStr;
      debug(`=> ${OL(str)}`);
    } else {
      debug("no HEREDOCs");
    }
    hNode.str = str;
    // --- NOTE: map() may return undef, meaning to ignore
    //     We must pass srcLevel since map() may use fetch()
    uobj = this.map(hNode);
    debug("return from TreeWalker.mapNonSpecial()", uobj);
    return uobj;
  }

  // ..........................................................
  // --- designed to override
  map(hNode) {
    return hNode.str;
  }

  // ..........................................................
  // --- can override to change how lines are joined
  joinExtensionLines(hNode, lExtLines) {
    var hContLine, j, len, nextStr, str;
    // --- modifies key str

    // --- There might be empty lines in lExtLines
    //     but we'll skip them here
    str = hNode.str;
    for (j = 0, len = lExtLines.length; j < len; j++) {
      hContLine = lExtLines[j];
      nextStr = hContLine.str;
      if (nonEmpty(nextStr)) {
        str += this.extSep(str, nextStr) + nextStr;
      }
    }
    hNode.str = str;
  }

  // ..........................................................
  handleHereDocsInLine(line, srcLevel) {
    var block, hOptions, j, lNewParts, lParts, len, part, result, str, uobj;
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
        uobj = mapHereDoc(block);
        assert(defined(uobj), "mapHereDoc returned undef");
        debug('mapped block', uobj);
        str = this.handleHereDoc(uobj, block);
        assert(isString(str), `str is ${OL(str)}`);
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
  handleHereDoc(uobj, block) {
    return uobj;
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
  mapCmd(hNode) {
    var argstr, cmd, isEnv, keep, lSkipLines, name, ok, prefix, srcLevel, uobj, value;
    debug("enter TreeWalker.mapCmd()", hNode);
    ({cmd, argstr, prefix, srcLevel} = hNode);
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
    uobj = super.mapCmd(hNode);
    debug("return from TreeWalker.mapCmd()", uobj);
    return uobj;
  }

  // ..........................................................
  adjustLevel(hNode) {
    var adjust, i, j, lNewMinuses, len, newLevel, ref, srcLevel;
    debug("enter adjustLevel()", hNode);
    srcLevel = hNode.srcLevel;
    debug("srcLevel", srcLevel);
    assert(isInteger(srcLevel, {
      min: 0
    }), `level is ${OL(srcLevel)}`);
    // --- Calculate the needed adjustment and new level
    debug("lMinuses", this.lMinuses);
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
    debug('new lMinuses', this.lMinuses);
    if (adjust === 0) {
      debug("return false from adjustLevel() - zero adjustment");
      return false;
    }
    assert(srcLevel >= adjust, `srcLevel=${srcLevel}, adjust=${adjust}`);
    newLevel = srcLevel - adjust;
    // --- Make adjustments to hNode
    hNode.level = newLevel;
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
    var discardStopLine, hNode, lLines, stopOn;
    //     Valid options:
    //        discard - discard ending line
    debug("enter TreeWalker.fetchLinesAtLevel()", atLevel, hOptions);
    assert(atLevel > 0, `atLevel is ${OL(atLevel)}`);
    discardStopLine = hOptions.discard || false;
    stopOn = hOptions.stopOn;
    if (defined(stopOn)) {
      assert(isString(stopOn), `stopOn is ${OL(stopOn)}`);
    }
    lLines = [];
    while (defined(hNode = this.fetch()) && debug('hNode from fetch()', hNode) && ((stopOn === undef) || (hNode.str !== stopOn)) && (isEmpty(hNode.str) || (hNode.level >= atLevel))) {
      debug("add to lLines", hNode);
      lLines.push(hNode);
    }
    // --- Cases:                            unfetch?
    //        1. line is undef                 NO
    //        2. line not a string             YES
    //        3. line == stopOn (& defined)    NO
    //        4. line nonEmpty and undented    YES
    if (defined(hNode)) {
      if (discardStopLine && (hNode.str === stopOn)) {
        debug(`discard stop line ${OL(stopOn)}`);
      } else {
        debug("unfetch last line", hNode);
        this.unfetch(hNode);
      }
    }
    debug("return from TreeWalker.fetchLinesAtLevel()", lLines);
    return lLines;
  }

  // ..........................................................
  fetchBlockAtLevel(atLevel, hOptions = {}) {
    var hNode, lLines, lRawLines, lUndentedLines, result;
    debug("enter TreeWalker.fetchBlockAtLevel()", atLevel, hOptions);
    lLines = this.fetchLinesAtLevel(atLevel, hOptions);
    debug('lLines', lLines);
    lRawLines = (function() {
      var j, len, results;
      results = [];
      for (j = 0, len = lLines.length; j < len; j++) {
        hNode = lLines[j];
        results.push(hNode.getLine(this.oneIndent));
      }
      return results;
    }).call(this);
    debug('lRawLines', lRawLines);
    lUndentedLines = undented(lRawLines, atLevel);
    debug("undented lLines", lUndentedLines);
    result = arrayToBlock(lUndentedLines);
    debug("return from TreeWalker.fetchBlockAtLevel()", result);
    return result;
  }

  // ========================================================================
  // --- override these for tree walking
  beginWalk(lStack) {
    return undef;
  }

  // ..........................................................
  visit(hNode, hUser, lStack) {
    var level, result, uobj;
    debug("enter visit()", hNode, hUser, lStack);
    ({uobj, level} = hNode);
    assert(isString(uobj), "uobj not a string");
    result = indented(uobj, level);
    debug("return from visit()", result);
    return result;
  }

  // ..........................................................
  endVisit(hNode, hUser, lStack) {
    debug("enter endVisit()", hNode, hUser, lStack);
    debug("return undef from endVisit()");
    return undef;
  }

  // ..........................................................
  visitEmptyLine(hNode, hUser, lStack) {
    debug("in TreeWalker.visitEmptyLine()");
    return '';
  }

  // ..........................................................
  endVisitEmptyLine(hNode, hUser, lStack) {
    debug("in TreeWalker.endVisitEmptyLine()");
    return undef;
  }

  // ..........................................................
  visitComment(hNode, hUser, lStack) {
    debug("in TreeWalker.visitComment()");
    return this.visit(hNode, hUser, lStack);
  }

  // ..........................................................
  endVisitComment(hNode, hUser, lStack) {
    debug("in TreeWalker.endVisitComment()");
    return undef;
  }

  // ..........................................................
  visitCmd(hNode, hUser, lStack) {
    debug("in TreeWalker.visitCmd()");
    return undef;
  }

  // ..........................................................
  endVisitCmd(hNode, hUser, lStack) {
    debug("in TreeWalker.endVisitCmd()");
    return undef;
  }

  // ..........................................................
  endWalk(lStack) {
    debug("in TreeWalker.endVisitCmd()");
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
      debug(`add text ${OL(text)}`);
      this.lLines.push(text);
    }
    debug("return from addText()");
  }

  // ..........................................................
  walk(hOptions = {}) {
    var hNode, i, lStack, level, ref, result, text;
    // --- Valid options: logNodes
    debug("enter walk()");
    // --- lStack is stack of:
    //        hNode: Node object
    //        hUser: {}
    //        }
    this.lLines = []; // --- resulting lines - added via @addText()
    lStack = [];
    debug("begin walk");
    if (defined(text = this.beginWalk(lStack))) {
      this.addText(text);
    }
    debug("getting lines");
    i = 0;
    ref = this.allMapped();
    for (hNode of ref) {
      if (hOptions.logNodes) {
        LOG(`hNode[${i}]`, hNode);
      } else {
        debug(`hNode[${i}]`, hNode);
      }
      i += 1;
      ({level} = hNode);
      while (lStack.length > level) {
        this.endVisitNode(lStack);
      }
      this.visitNode(hNode, lStack);
    }
    while (lStack.length > 0) {
      this.endVisitNode(lStack);
    }
    if (defined(text = this.endWalk(lStack))) {
      this.addText(text);
    }
    if (nonEmpty(this.lLines)) {
      result = arrayToBlock(this.lLines);
    } else {
      result = '';
    }
    debug("return from walk()", result);
    return result;
  }

  // ..........................................................
  visitNode(hNode, lStack) {
    var hUser, text, type;
    debug("enter visitNode()", hNode, lStack);
    // --- Create a user hash that the user can add to/modify
    //     and will see again at endVisit
    hUser = {};
    if ((type = hNode.type)) {
      debug(`type = ${type}`);
      text = this.visitSpecial(type, hNode, hUser, lStack);
    } else {
      debug("no type");
      text = this.visit(hNode, hUser, lStack);
    }
    if (defined(text)) {
      this.addText(text);
    }
    lStack.push({hNode, hUser});
    debug("return from visitNode()");
  }

  // ..........................................................
  endVisitNode(lStack) {
    var hNode, hUser, text, type;
    debug("enter endVisitNode()", lStack);
    assert(nonEmpty(lStack), "stack is empty");
    ({hNode, hUser} = lStack.pop());
    if ((type = hNode.type)) {
      text = this.endVisitSpecial(type, hNode, hUser, lStack);
    } else {
      text = this.endVisit(hNode, hUser, lStack);
    }
    if (defined(text)) {
      this.addText(text);
    }
    debug("return from endVisitNode()");
  }

  // ..........................................................
  visitSpecial(type, hNode, hUser, lStack) {
    var func, result, visiter;
    debug("enter TreeWalker.visitSpecial()", type, hNode, hUser, lStack);
    visiter = this.hSpecialVisitTypes[type].visiter;
    assert(defined(visiter), `No such type: ${OL(type)}`);
    func = visiter.bind(this);
    assert(isFunction(func), "not a function");
    result = func(hNode, hUser, lStack);
    debug("return from TreeWalker.visitSpecial()", result);
    return result;
  }

  // ..........................................................
  endVisitSpecial(type, hNode, hUser, lStack) {
    var func;
    func = this.hSpecialVisitTypes[type].endVisiter.bind(this);
    return func(hNode, hUser, lStack);
  }

  // ..........................................................
  getBlock(hOptions = {}) {
    var block, result;
    // --- Valid options: logNodes
    debug("enter getBlock()");
    block = this.walk(hOptions);
    debug('block', block);
    result = this.finalizeBlock(block);
    debug("return from getBlock()", result);
    return result;
  }

};
