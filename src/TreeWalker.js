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
  isString,
  isNumber,
  isEmpty,
  nonEmpty,
  isArray,
  isHash
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
  mapHereDoc,
  addHereDocType
} from '@jdeighan/mapper/heredoc';

import {
  FuncHereDoc
} from '@jdeighan/mapper/func';

import {
  TAMLHereDoc
} from '@jdeighan/mapper/taml';

import {
  RunTimeStack
} from '@jdeighan/mapper/stack';

// ===========================================================================
//   class TreeWalker
//      - map() returns {uobj, level, lineNum} or undef
//   to use, override:
//      mapStr(str, level) - returns user object, default returns str
//      handleCmd()
//      beginWalk() -
//      visit(uobj, level, lineNum) -
//      endVisit(uobj, level, lineNum) -
//      endWalk() -
export var TreeWalker = class TreeWalker extends Mapper {
  // ..........................................................
  // --- Should always return either:
  //        undef
  //        object with {uobj, level, lineNum}
  // --- Will only receive non-special lines
  map(item) {
    var hResult, lExtLines, level, lineNum, newstr, str, uobj;
    debug("enter map()", item);
    // --- a TreeWalker makes no sense unless items are strings
    assert(isString(item), `non-string: ${OL(item)}`);
    lineNum = this.lineNum; // save in case we fetch more lines
    [level, str] = splitLine(item);
    debug(`split: level = ${OL(level)}, str = ${OL(str)}`);
    assert(nonEmpty(str), "empty string should be special");
    // --- check for extension lines
    debug("check for extension lines");
    lExtLines = this.fetchLinesAtLevel(level + 2);
    assert(isArray(lExtLines), "lExtLines not an array");
    if (nonEmpty(lExtLines)) {
      newstr = this.joinExtensionLines(str, lExtLines);
      if (newstr !== str) {
        str = newstr;
        debug(`=> ${OL(str)}`);
      }
    }
    // --- handle HEREDOCs
    debug("check for HEREDOC");
    if (str.indexOf('<<<') >= 0) {
      hResult = this.handleHereDoc(str, level);
      // --- NOTE: hResult.lObjects is not currently used
      //           but I want to use it in the future to
      //           prevent having to construct an object from the line
      if (hResult.line !== str) {
        str = hResult.line;
        debug(`=> ${OL(str)}`);
      }
    }
    // --- NOTE: mapStr() may return undef, meaning to ignore
    item = this.mapStr(str, level);
    if (defined(item)) {
      uobj = {level, lineNum, item};
      debug("return from map()", uobj);
      return uobj;
    } else {
      debug("return undef from map()");
      return undef;
    }
  }

  // ..........................................................
  // --- designed to override
  mapStr(str, level) {
    return str;
  }

  // ..........................................................
  joinExtensionLines(line, lExtLines) {
    var contLine, i, len;
// --- There might be empty lines in lExtLines
//     but we'll skip them here
    for (i = 0, len = lExtLines.length; i < len; i++) {
      contLine = lExtLines[i];
      if (nonEmpty(contLine)) {
        line += ' ' + contLine.trim();
      }
    }
    return line;
  }

  // ..........................................................
  handleHereDoc(line, level) {
    var hResult, i, lLines, lNewParts, lObjects, lParts, len, part;
    // --- Indentation has been removed from line
    // --- Find each '<<<' and replace with result of mapHereDoc()
    debug("enter handleHereDoc()", line, level);
    assert(isString(line), "not a string");
    lParts = lineToParts(line);
    debug('lParts', lParts);
    lObjects = [];
    lNewParts = []; // to be joined to form new line
    for (i = 0, len = lParts.length; i < len; i++) {
      part = lParts[i];
      if (part === '<<<') {
        debug(`get HEREDOC lines at level ${level + 1}`);
        lLines = this.fetchLinesAtLevel(level + 1, ''); // stop on blank line
        lLines = undented(lLines, level + 1);
        debug('lLines', lLines);
        hResult = mapHereDoc(arrayToBlock(lLines));
        debug('hResult', hResult);
        lObjects.push(hResult.obj);
        lNewParts.push(hResult.str);
      } else {
        lNewParts.push(part); // keep as is
      }
    }
    hResult = {
      line: lNewParts.join(''),
      lObjects: lObjects
    };
    debug("return from handleHereDoc", hResult);
    return hResult;
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
    var isEnv, item, lResult, name, uobj, value;
    // --- h has keys 'cmd','argstr' and 'prefix'
    //     but may contain additional keys
    debug("enter TreeWalker.handleCmd()", h);
    // --- Handle our commands, returning if found
    switch (cmd) {
      case 'ifdef':
      case 'ifndef':
        lResult = this.splitDef(argstr);
        assert(defined(lResult), `Invalid ${cmd}, argstr=${OL(argstr)}`);
        [isEnv, name, value] = lResult;
        if (isEnv) {
          if (defined(value)) {
            item = {cmd, isEnv, name, value};
          } else {
            item = {cmd, isEnv, name};
          }
        } else {
          if (defined(value)) {
            item = {cmd, name, value};
          } else {
            item = {cmd, name};
          }
        }
        uobj = {
          lineNum: this.lineNum,
          level: indentLevel(prefix),
          item
        };
        debug("return from TreeWalker.handleCmd()", uobj);
        return uobj;
    }
    debug("call super");
    uobj = super.handleCmd(cmd, argstr, prefix, h);
    debug("return super from TreeWalker.handleCmd()", uobj);
    return uobj;
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
      return [isEnv, name, value];
    } else {
      return undef;
    }
  }

  // ..........................................................
  fetchLinesAtLevel(atLevel, stopOn = undef) {
    var item, lLines;
    // --- Does NOT remove any indentation
    debug(`enter TreeWalker.fetchLinesAtLevel(${OL(atLevel)}, ${OL(stopOn)})`);
    assert(atLevel > 0, "atLevel is 0");
    lLines = [];
    while (defined(item = this.fetch()) && debug(`item = ${OL(item)}`) && isString(item) && ((stopOn === undef) || (item !== stopOn)) && debug("OK") && (isEmpty(item) || (indentLevel(item) >= atLevel))) {
      debug(`push ${OL(item)}`);
      lLines.push(item);
    }
    // --- Cases:                            unfetch?
    //        1. item is undef                 NO
    //        2. item not a string             YES
    //        3. item == stopOn (& defined)    NO
    //        4. item nonEmpty and undented    YES
    if ((item === undef) || (item === stopOn)) {
      debug("don't unfetch");
    } else {
      debug("do unfetch");
      this.unfetch(item);
    }
    debug("return from TreeWalker.fetchLinesAtLevel()", lLines);
    return lLines;
  }

  // ..........................................................
  fetchBlockAtLevel(atLevel, stopOn = undef) {
    var lLines, result;
    debug(`enter TreeWalker.fetchBlockAtLevel(${OL(atLevel)})`);
    lLines = this.fetchLinesAtLevel(atLevel, stopOn);
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
  visit(uobj, level, lineNum) {
    var result;
    debug("enter visit()", uobj, level, lineNum);
    assert(level >= 0, `level = ${OL(level)}`);
    result = indented(uobj, level);
    debug("return from visit()", result);
    return result;
  }

  // ..........................................................
  endVisit(uobj, level, lineNum) {
    return undef;
  }

  // ..........................................................
  endWalk() {
    return undef;
  }

  // ..........................................................
  // ..........................................................
  isDefined(uobj) {
    var isEnv, name, value;
    ({name, value, isEnv} = uobj);
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
  visitNode(node, hUser) {
    var cmd, level, line, lineNum, uobj;
    debug("enter visitNode()", node, hUser);
    ({uobj, level, lineNum} = node);
    debug(`level = ${OL(level)}`);
    debug(`lineNum = ${OL(lineNum)}`);
    cmd = this.whichCmd(uobj);
    debug(`cmd = ${OL(cmd)}`);
    switch (cmd) {
      case 'ifdef':
        this.doVisit = this.isDefined(uobj);
        this.minus += 1;
        break;
      case 'ifndef':
        this.doVisit = !this.isDefined(uobj);
        this.minus += 1;
        break;
      default:
        if (this.doVisit) {
          line = this.visit(uobj, level - this.minus, lineNum, hUser);
          if (defined(line)) {
            this.addLine(line);
          }
        }
    }
    this.lStack.push({
      node,
      hUser,
      doVisit: this.doVisit
    });
    debug("return from visitNode()");
  }

  // ..........................................................
  endVisitNode() {
    var doVisit, hUser, level, line, lineNum, node, uobj;
    debug("enter endVisitNode()");
    ({node, hUser, doVisit} = this.lStack.pop());
    ({uobj, level, lineNum} = node);
    switch (this.whichCmd(uobj)) {
      case 'ifdef':
      case 'ifndef':
        this.doVisit = doVisit;
        this.minus -= 1;
        break;
      default:
        if (this.doVisit) {
          line = this.endVisit(uobj, level - this.minus, lineNum, hUser);
          if (defined(line)) {
            this.addLine(line);
          }
        }
    }
    debug("return from endVisitNode()");
  }

  // ..........................................................
  whichCmd(uobj) {
    if (isHash(uobj) && uobj.hasOwnProperty('cmd')) {
      return uobj.cmd;
    }
    return undef;
  }

  // ..........................................................
  walk() {
    var hUser, line, node, ref, result;
    debug("enter walk()");
    // --- @lStack is stack of {
    //        node: {uobj, level, lineNum},
    //        hUser: {_parent: <parent node>, ...}
    //        }
    this.lLines = []; // --- resulting lines
    
    // --- Initialize these here, but they're managed in
    //     @visitNode() and @endVisitNode()
    this.lStack = [];
    this.minus = 0; // --- subtract this from level in visit, endVisit
    this.doVisit = true; // --- if false, skip visiting
    debug("begin walk");
    line = this.beginWalk();
    if (defined(line)) {
      this.addLine(line);
    }
    debug("getting nodes");
    ref = this.allMapped();
    for (node of ref) {
      while (this.lStack.length > node.level) {
        this.endVisitNode();
      }
      // --- Create a user hash that the user can add to/modify
      //     and contains a reference to the parent node
      //     and will see again at endVisit
      if (this.lStack.length === 0) {
        hUser = {};
      } else {
        hUser = {
          _parent: this.lStack[this.lStack.length - 1].node
        };
      }
      this.visitNode(node, hUser);
    }
    while (this.lStack.length > 0) {
      this.endVisitNode();
    }
    line = this.endWalk();
    if (defined(line)) {
      this.addLine(line);
    }
    result = arrayToBlock(this.lLines);
    this.lStack = undef;
    this.minus = undef;
    this.doVisit = undef;
    debug("return from walk()", result);
    return result;
  }

  // ..........................................................
  addLine(line) {
    assert(defined(line), "line is undef");
    debug(`enter addLine(${OL(line)})`, line);
    if (isArray(line)) {
      debug("line is an array");
      this.lLines.push(...line);
    } else {
      this.lLines.push(line);
    }
    debug("return from addLine()");
  }

  // ..........................................................
  getBlock() {
    var result;
    debug("enter getBlock()");
    result = this.walk();
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
    this.lTrace = ["begin"]; // an array of strings
  }

  // ..........................................................
  visit(uobj, level, lineNum) {
    this.lTrace.push("|.".repeat(level) + `> ${OL(uobj)}`);
  }

  // ..........................................................
  endVisit(uobj, level, lineNum) {
    this.lTrace.push("|.".repeat(level) + `< ${OL(uobj)}`);
  }

  // ..........................................................
  endWalk() {
    var block;
    this.lTrace.push("end");
    block = arrayToBlock(this.lTrace);
    this.lTrace = undef;
    return block;
  }

};

// ---------------------------------------------------------------------------
addHereDocType(new TAMLHereDoc()); //  ---

addHereDocType(new FuncHereDoc()); //  () ->
