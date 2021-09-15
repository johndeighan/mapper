// Generated by CoffeeScript 2.5.1
// StringInput.coffee
var hExtToEnvVar;

import {
  strict as assert
} from 'assert';

import fs from 'fs';

import pathlib from 'path';

import {
  dirname,
  resolve,
  parse as parse_fname
} from 'path';

import {
  undef,
  pass,
  croak,
  isString,
  isEmpty,
  nonEmpty,
  isComment,
  isArray,
  isHash,
  isInteger,
  deepCopy,
  stringToArray,
  arrayToString,
  oneline,
  escapeStr
} from '@jdeighan/coffee-utils';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  slurp,
  pathTo
} from '@jdeighan/coffee-utils/fs';

import {
  splitLine,
  indented,
  undented
} from '@jdeighan/coffee-utils/indent';

import {
  debug,
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  joinBlocks
} from '@jdeighan/coffee-utils/block';

import {
  markdownify
} from '@jdeighan/string-input/markdown';

import {
  isTAML,
  taml
} from '@jdeighan/string-input/taml';

// ---------------------------------------------------------------------------
//   class StringFetcher - stream in lines from a string
//                         handles #include
export var StringFetcher = class StringFetcher {
  constructor(content, hOptions1 = {}) {
    var base, filename;
    this.hOptions = hOptions1;
    // --- Valid options:
    //        filename
    if (isEmpty(content)) {
      this.lBuffer = [];
    } else if (isString(content)) {
      this.lBuffer = stringToArray(content);
    } else if (isArray(content)) {
      // -- make a deep copy
      this.lBuffer = deepCopy(content);
    } else {
      croak("StringFetcher(): content must be array or string", "CONTENT", content);
    }
    debug("in constructor: BUFFER", this.lBuffer);
    this.lineNum = 0;
    ({filename} = this.hOptions);
    if (filename) {
      try {
        // --- We only want the bare filename
        ({base} = pathlib.parse(filename));
        this.filename = base;
      } catch (error) {
        this.filename = filename;
      }
    } else {
      this.filename = 'unit test';
    }
    // --- for handling #include
    this.altInput = undef;
    this.altPrefix = undef; // prefix prepended to lines from alt
  }

  
    // ..........................................................
  fetch() {
    var _, contents, fname, lMatches, line, prefix, result;
    debug("enter fetch()");
    if (this.altInput) {
      assert(this.altPrefix != null, "fetch(): alt intput without alt prefix");
      line = this.altInput.fetch();
      if (line != null) {
        result = `${this.altPrefix}${line}`;
        debug(`return '${escapeStr(result)}' from fetch() - alt`);
        return result;
      } else {
        this.altInput = undef; // it's exhausted
      }
    }
    if (this.lBuffer.length === 0) {
      debug("return undef from fetch() - empty buffer");
      return undef;
    }
    // --- @lBuffer is not empty here
    line = this.lBuffer.shift();
    this.lineNum += 1;
    if (lMatches = line.match(/^(\s*)\#include\s+(\S.*)$/)) {
      [_, prefix, fname] = lMatches;
      debug(`#include ${fname} with prefix '${escapeStr(prefix)}'`);
      assert(!this.altInput, "fetch(): altInput already set");
      contents = getFileContents(fname);
      this.altInput = new StringFetcher(contents);
      this.altPrefix = prefix;
      debug(`alt input created with prefix '${escapeStr(prefix)}'`);
      line = this.altInput.fetch();
      if (line != null) {
        return `${this.altPrefix}${line}`;
      } else {
        return this.fetch(); // recursive call
      }
    } else {
      debug(`return ${oneline(line)} from fetch()`);
      return line;
    }
  }

  // ..........................................................
  // --- Put a line back into lBuffer, to be fetched later
  unfetch(line) {
    debug(`enter unfetch('${escapeStr(line)}')`);
    this.lBuffer.unshift(line);
    this.lineNum -= 1;
    debug('return from unfetch()');
  }

  // ..........................................................
  nextLine() {
    var line;
    line = this.fetch();
    this.unfetch(line);
    return line;
  }

  // ..........................................................
  getPositionInfo() {
    if (this.altInput) {
      return this.altInput.getPositionInfo();
    } else {
      return {
        file: this.filename,
        lineNum: this.lineNum
      };
    }
  }

  // ..........................................................
  fetchAll() {
    var lLines, line;
    lLines = [];
    while ((line = this.fetch()) != null) {
      lLines.push(line);
    }
    return lLines;
  }

  // ..........................................................
  fetchAllBlock() {
    var lLines;
    lLines = this.fetchAll();
    return arrayToString(lLines);
  }

};

// ===========================================================================
//   class StringInput
//      - keep track of indentation
//      - allow mapping of lines, including skipping lines
//      - implement look ahead via peek()
export var StringInput = class StringInput extends StringFetcher {
  constructor(content, hOptions = {}) {
    // --- Valid options:
    //        filename
    super(content, hOptions);
    this.lookahead = undef; // --- lookahead token, placed by unget
    
    // --- cache in case getAll() is called multiple times
    this.lAllPairs = undef;
  }

  // ..........................................................
  unget(pair) {
    // --- pair will always be [<item>, <level>]
    //     <item> can be anything - i.e. it's been mapped
    debug('enter unget() with', pair);
    assert(this.lookahead == null, "unget(): there's already a lookahead");
    this.lookahead = pair;
    debug('return from unget()');
  }

  // ..........................................................
  peek() {
    var pair;
    debug('enter peek():');
    if (this.lookahead != null) {
      debug("return lookahead from peek");
      return this.lookahead;
    }
    pair = this.get();
    if (pair == null) {
      debug("return from peek() - undef");
      return undef;
    }
    this.unget(pair);
    debug(`return ${oneline(pair)} from peek`);
    return pair;
  }

  // ..........................................................
  skip() {
    debug('enter skip():');
    if (this.lookahead != null) {
      this.lookahead = undef;
      debug("return from skip: clear lookahead");
      return;
    }
    this.get();
    debug('return from skip()');
  }

  // ..........................................................
  // --- designed to override with a mapping method
  //     which can map to any valid JavaScript value
  mapLine(line, level) {
    assert((line != null) && isString(line), "mapLine(): not a string");
    debug(`in default mapLine('${escapeStr(line)}', ${level})`);
    return line;
  }

  // ..........................................................
  get() {
    var level, line, newline, result, saved;
    debug(`enter get() - src ${this.filename}`);
    if (this.lookahead != null) {
      saved = this.lookahead;
      this.lookahead = undef;
      debug("return lookahead pair from get()");
      return saved;
    }
    line = this.fetch(); // will handle #include
    debug("LINE", line);
    if (line == null) {
      debug("return from get() with undef at EOF");
      return undef;
    }
    [level, newline] = splitLine(line);
    result = this.mapLine(newline, level);
    debug(`MAP: '${newline}' => ${oneline(result)}`);
    // --- if mapLine() returns undef, we skip that line
    while ((result == null) && (this.lBuffer.length > 0)) {
      line = this.fetch();
      [level, newline] = splitLine(line);
      result = this.mapLine(newline, level);
      debug(`MAP: '${newline}' => ${oneline(result)}`);
    }
    if (result != null) {
      debug(`return ${oneline(result)}, ${level} from get()`);
      return [result, level];
    } else {
      debug("return undef from get()");
      return undef;
    }
  }

  // ..........................................................
  // --- Fetch a block of text at level or greater than 'level'
  //     as one long string
  // --- Designed to use in mapLine()
  fetchBlock(atLevel) {
    var lLines, level, line, result, retval, str;
    debug(`enter fetchBlock(${atLevel})`);
    lLines = [];
    // --- NOTE: I absolutely hate using a backslash for line continuation
    //           but CoffeeScript doesn't continue while there is an
    //           open parenthesis like Python does :-(
    line = undef;
    while ((line = this.fetch()) != null) {
      debug(`LINE IS ${oneline(line)}`);
      assert(isString(line), `StringInput.fetchBlock(${atLevel}) - not a string: ${line}`);
      if (isEmpty(line)) {
        debug("empty line");
        lLines.push('');
        continue;
      }
      [level, str] = splitLine(line);
      debug(`LOOP: level = ${level}, str = ${oneline(str)}`);
      if (level < atLevel) {
        this.unfetch(line);
        debug("RESULT: unfetch the line");
        break;
      }
      result = indented(str, level - atLevel);
      debug("RESULT", result);
      lLines.push(result);
    }
    retval = lLines.join('\n');
    debug("return from fetchBlock with", retval);
    return retval;
  }

  // ..........................................................
  getAll() {
    var lPairs, pair;
    debug("enter getAll()");
    if (this.lAllPairs != null) {
      debug("return cached lAllPairs from getAll()");
      return this.lAllPairs;
    }
    lPairs = [];
    while ((pair = this.get()) != null) {
      lPairs.push(pair);
    }
    this.lAllPairs = lPairs;
    debug(`return ${lPairs.length} pairs from getAll()`);
    return lPairs;
  }

  // ..........................................................
  getAllText() {
    var lLines, level, line;
    lLines = (function() {
      var j, len1, ref, results;
      ref = this.getAll();
      results = [];
      for (j = 0, len1 = ref.length; j < len1; j++) {
        [line, level] = ref[j];
        results.push(indented(line, level));
      }
      return results;
    }).call(this);
    return arrayToString(lLines);
  }

};

// ===========================================================================
export var SmartInput = class SmartInput extends StringInput {
  // - removes blank lines and comments (but can be overridden)
  // - joins continuation lines
  // - handles HEREDOCs
  constructor(content, hOptions = {}) {
    // --- Valid options:
    //        filename
    super(content, hOptions);
    // --- This should only be used in mapLine(), where
    //     it keeps track of the level we're at, to be passed
    //     to handleEmptyLine() since the empty line itself
    //     is always at level 0
    this.curLevel = 0;
  }

  // ..........................................................
  getContLines(curlevel) {
    var lLines, nextLevel, nextLine, nextStr;
    lLines = [];
    while (((nextLine = this.fetch()) != null) && (nonEmpty(nextLine)) && ([nextLevel, nextStr] = splitLine(nextLine)) && (nextLevel >= curlevel + 2)) {
      lLines.push(nextStr);
    }
    if (nextLine != null) {
      // --- we fetched a line we didn't want
      this.unfetch(nextLine);
    }
    return lLines;
  }

  // ..........................................................
  joinContLines(line, lContLines) {
    if (isEmpty(lContLines)) {
      return line;
    }
    return line + ' ' + lContLines.join(' ');
  }

  // ..........................................................
  handleEmptyLine(level) {
    debug("in default handleEmptyLine()");
    return undef; // skip blank lines by default
  }

  
    // ..........................................................
  handleComment(line, level) {
    debug("in default handleComment()");
    return undef; // skip comments by default
  }

  
    // ..........................................................
  // --- designed to override with a mapping method
  //     NOTE: line includes the indentation
  mapLine(line, level) {
    var lContLines, orgLineNum, result;
    debug(`enter mapLine('${escapeStr(line)}', ${level})`);
    assert(line != null, "mapLine(): line is undef");
    assert(isString(line), `mapLine(): ${oneline(line)} not a string`);
    if (isEmpty(line)) {
      debug("return undef from mapLine() - empty");
      return this.handleEmptyLine(this.curLevel);
    }
    if (isComment(line)) {
      debug("return undef from mapLine() - comment");
      return this.handleComment(line, level);
    }
    orgLineNum = this.lineNum;
    this.curLevel = level;
    // --- Merge in any continuation lines
    debug("check for continuation lines");
    lContLines = this.getContLines(level);
    if (nonEmpty(lContLines)) {
      line = this.joinContLines(line, lContLines);
      debug(`line becomes ${oneline(line)}`);
    }
    // --- handle HEREDOCs
    debug("check for HEREDOC");
    if (line.indexOf('<<<') !== -1) {
      line = this.handleHereDoc(line, level);
      debug(`line becomes ${oneline(line)}`);
    }
    debug("mapping string");
    result = this.mapString(line, level);
    debug(`return ${oneline(result)} from mapLine()`);
    return result;
  }

  // ..........................................................
  mapString(line, level) {
    // --- NOTE: line has indentation removed
    //     when overriding, may return anything
    //     return undef to generate nothing
    assert(isString(line), `default mapString(): ${oneline(line)} is not a string`);
    return indented(line, level);
  }

  // ..........................................................
  heredocStr(block) {
    // --- return replacement string for '<<<', given a block
    if (isTAML(block)) {
      return JSON.stringify(taml(block));
    } else {
      return block.replace(/\n/sg, ' ');
    }
  }

  // ..........................................................
  handleHereDoc(line, level) {
    var block, lLines, lParts, newstr, part, pos, result, start;
    // --- Indentation is removed from line
    // --- Find each '<<<' and replace with result of heredocStr()
    assert(isString(line), "handleHereDoc(): not a string");
    debug(`enter handleHereDoc(${oneline(line)})`);
    lParts = []; // joined at the end
    pos = 0;
    while ((start = line.indexOf('<<<', pos)) !== -1) {
      part = line.substring(pos, start);
      debug(`PUSH ${oneline(part)}`);
      lParts.push(part);
      lLines = this.getHereDocLines(level);
      assert(isArray(lLines), "handleHereDoc(): lLines not an array");
      debug(`HEREDOC lines: ${oneline(lLines)}`);
      if (lLines.length > 0) {
        block = arrayToString(undented(lLines));
        newstr = this.heredocStr(block);
        assert(isString(newstr), "handleHereDoc(): newstr not a string");
        debug(`PUSH ${oneline(newstr)}`);
        lParts.push(newstr);
      }
      pos = start + 3;
    }
    // --- If no '<<<' in string, just return original line
    if (pos === 0) {
      debug("return from handleHereDoc - no <<< in line");
      return line;
    }
    assert(line.indexOf('<<<', pos) === -1, "handleHereDoc(): Not all HEREDOC markers were replaced" + `in '${line}'`);
    part = line.substring(pos, line.length);
    debug(`PUSH ${oneline(part)}`);
    lParts.push(part);
    result = lParts.join('');
    debug("return from handleHereDoc", result);
    return result;
  }

  // ..........................................................
  addHereDocLine(lLines, line) {
    if (line.trim() === '.') {
      lLines.push('');
    } else {
      lLines.push(line);
    }
  }

  // ..........................................................
  getHereDocLines(level) {
    var firstLineLevel, lLines, line, lineLevel, str;
    // --- Get all lines until empty line is found
    //     BUT treat line of a single period as empty line
    //     1st line should be indented level+1, or be empty
    lLines = [];
    firstLineLevel = undef;
    while ((this.lBuffer.length > 0) && !isEmpty(this.lBuffer[0])) {
      line = this.fetch();
      [lineLevel, str] = splitLine(line);
      if (firstLineLevel != null) {
        assert(lineLevel >= firstLineLevel, "invalid indentation in HEREDOC section");
        str = indented(str, lineLevel - firstLineLevel);
      } else {
        // --- This is the first line of the HEREDOC section
        if (isEmpty(str)) {
          return [];
        }
        assert(lineLevel === level + 1, `getHereDocLines(): 1st line indentation should be ${level + 1}`);
        firstLineLevel = lineLevel;
      }
      this.addHereDocLine(lLines, str);
    }
    if (this.lBuffer.length > 0) {
      this.fetch(); // empty line
    }
    return lLines;
  }

};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// --- To derive a class from this:
//        1. Extend this class
//        2. Override mapNode(), which gets the line with
//           any continuation lines appended, plus any
//           HEREDOC sections expanded
//        3. If desired, override handleHereDoc, which patches
//           HEREDOC lines into the original string
export var PLLParser = class PLLParser extends SmartInput {
  constructor(content, hOptions = {}) {
    // --- Valid options:
    //        filename
    super(content, hOptions);
    // --- Cached tree, in case getTree() is called multiple times
    this.tree = undef;
  }

  // ..........................................................
  mapString(line, level) {
    var result;
    result = this.mapNode(line, level);
    if (result != null) {
      return [level, this.lineNum, result];
    } else {
      // --- We need to skip over all following nodes
      //     at a higher level than this one
      this.fetchBlock(level + 1);
      return undef;
    }
  }

  // ..........................................................
  mapNode(line, level) {
    return line;
  }

  // ..........................................................
  getAll() {
    var lItems, lPairs, pair;
    // --- This returns a list of pairs, but
    //     we don't need the level anymore since it's
    //     also stored in the node
    lPairs = super.getAll();
    debug("lPairs", lPairs);
    lItems = (function() {
      var j, len1, results;
      results = [];
      for (j = 0, len1 = lPairs.length; j < len1; j++) {
        pair = lPairs[j];
        results.push(pair[0]);
      }
      return results;
    })();
    debug("lItems", lItems);
    return lItems;
  }

  // ..........................................................
  getTree() {
    var lItems, tree;
    debug("enter getTree()");
    if (this.tree != null) {
      debug("return cached tree from getTree()");
      return this.tree;
    }
    lItems = this.getAll();
    assert(lItems != null, "lItems is undef");
    assert(isArray(lItems), "getTree(): lItems is not an array");
    // --- treeify will consume its input, so we'll first
    //     make a deep copy
    tree = treeify(deepCopy(lItems));
    debug("TREE", tree);
    this.tree = tree;
    debug("return from getTree()", tree);
    return tree;
  }

};

// ---------------------------------------------------------------------------
// Each item must be a sub-array with 3 items: [<level>, <lineNum>, <node>]
// If a predicate is supplied, it must return true for any <node>
export var treeify = function(lItems, atLevel = 0, predicate = undef) {
  var body, err, h, item, lNodes, level, lineNum, node;
  // --- stop when an item of lower level is found, or at end of array
  debug(`enter treeify(${atLevel})`);
  debug('lItems', lItems);
  try {
    checkTree(lItems, predicate);
    debug("check OK");
  } catch (error) {
    err = error;
    croak(err, 'lItems', lItems);
  }
  lNodes = [];
  while ((lItems.length > 0) && (lItems[0][0] >= atLevel)) {
    item = lItems.shift();
    [level, lineNum, node] = item;
    if (level !== atLevel) {
      croak(`treeify(): item at level ${level}, should be ${atLevel}`, "TREE", lItems);
    }
    h = {node, lineNum};
    body = treeify(lItems, atLevel + 1);
    if (body != null) {
      h.body = body;
    }
    lNodes.push(h);
  }
  if (lNodes.length === 0) {
    debug("return undef from treeify()");
    return undef;
  } else {
    debug(`return ${lNodes.length} nodes from treeify()`, lNodes);
    return lNodes;
  }
};

// ---------------------------------------------------------------------------
export var checkTree = function(lItems, predicate) {
  var i, item, j, len, len1, level, lineNum, node;
  // --- Each item should be a sub-array with 3 items:
  //        1. an integer - level
  //        2. an integer - a line number
  //        3. anything, but if predicate is defined, it must return true
  assert(isArray(lItems), "treeify(): lItems is not an array");
  for (i = j = 0, len1 = lItems.length; j < len1; i = ++j) {
    item = lItems[i];
    assert(isArray(item), `treeify(): lItems[${i}] is not an array`);
    len = item.length;
    assert(len === 3, `treeify(): item has length ${len}`);
    [level, lineNum, node] = item;
    assert(isInteger(level), "checkTree(): level not an integer");
    assert(isInteger(lineNum), "checkTree(): lineNum not an integer");
    if (predicate != null) {
      assert(predicate(node), "checkTree(): node fails predicate");
    }
  }
};

// ---------------------------------------------------------------------------
hExtToEnvVar = {
  '.md': 'dir_markdown',
  '.taml': 'dir_data',
  '.txt': 'dir_data'
};

// ---------------------------------------------------------------------------
export var getFileContents = function(fname, convert = false) {
  var base, contents, dir, envvar, ext, fullpath, root;
  debug(`enter getFileContents('${fname}')`);
  ({root, dir, base, ext} = parse_fname(fname.trim()));
  assert(!root && !dir, "getFileContents():" + ` root='${root}', dir='${dir}'` + " - full path not allowed");
  envvar = hExtToEnvVar[ext];
  debug(`envvar = '${envvar}'`);
  assert(envvar, `getFileContents() doesn't work for ext '${ext}'`);
  dir = process.env[envvar];
  debug(`dir = '${dir}'`);
  assert(dir, `env var '${envvar}' not set for file extension '${ext}'`);
  fullpath = pathTo(base, dir); // guarantees that file exists
  debug(`fullpath = '${fullpath}'`);
  assert(fullpath, `getFileContents(): Can't find file ${fname}`);
  contents = slurp(fullpath);
  if (!convert) {
    debug("return from getFileContents() - not converting");
    return contents;
  }
  switch (ext) {
    case '.md':
      contents = markdownify(contents);
      break;
    case '.taml':
      contents = taml(contents);
      break;
    case '.txt':
      pass;
      break;
    default:
      croak(`getFileContents(): No handler for ext '${ext}'`);
  }
  debug("return from getFileContents()", contents);
  return contents;
};
