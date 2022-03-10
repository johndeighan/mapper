// Generated by CoffeeScript 2.6.1
// StringInput.coffee
var hExtToEnvVar;

import fs from 'fs';

import pathlib from 'path';

import {
  assert,
  undef,
  pass,
  croak,
  isString,
  isEmpty,
  nonEmpty,
  escapeStr,
  isComment,
  isArray,
  isHash,
  isInteger,
  deepCopy,
  OL,
  CWS
} from '@jdeighan/coffee-utils';

import {
  blockToArray,
  arrayToBlock,
  firstLine,
  remainingLines
} from '@jdeighan/coffee-utils/block';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  slurp,
  pathTo,
  mydir,
  parseSource,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  splitLine,
  indented,
  undented,
  indentLevel
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

import {
  mapHereDoc
} from '@jdeighan/string-input/heredoc';

// ---------------------------------------------------------------------------

// --- Default env vars for #include files
hExtToEnvVar = {
  '.md': 'DIR_MARKDOWN',
  '.taml': 'DIR_DATA',
  '.txt': 'DIR_DATA'
};

// ---------------------------------------------------------------------------
//   class StringFetcher - stream in lines from a string
//                         handles #include
export var StringFetcher = class StringFetcher {
  constructor(content, source = 'unit test') {
    var dir, filename, hSourceInfo, i, j, lPatchedBuffer, len1, line, ref;
    // --- Has keys: dir, filename, stub, ext
    //     If source is 'unit test', just returns:
    //     { filename: 'unit test', stub: 'unit test'}
    hSourceInfo = parseSource(source);
    filename = hSourceInfo.filename;
    assert(filename, "StringFetcher: parseSource returned no filename");
    this.filename = filename;
    this.hSourceInfo = hSourceInfo;
    if (content == null) {
      if (hSourceInfo.fullpath) {
        content = slurp(hSourceInfo.fullpath);
        this.lBuffer = blockToArray(content);
      } else {
        croak("StringFetcher: no source or fullpath");
      }
    } else if (isEmpty(content)) {
      this.lBuffer = [];
    } else if (isString(content)) {
      this.lBuffer = blockToArray(content);
    } else if (isArray(content)) {
      // -- make a deep copy
      this.lBuffer = deepCopy(content);
    } else {
      croak("StringFetcher(): content must be array or string", "CONTENT", content);
    }
    // --- patch {{FILE}} and {{LINE}}
    dir = hSourceInfo.dir;
    lPatchedBuffer = [];
    ref = this.lBuffer;
    for (i = j = 0, len1 = ref.length; j < len1; i = ++j) {
      line = ref[i];
      // --- patch(patch(line, '{{FILE}}', @filename), '{{LINE}}', i+1)
      line = line.replace('{{FILE}}', this.filename);
      line = line.replace('{{LINE}}', i + 1);
      if (dir) {
        line = line.replace('{{DIR}}', dir);
      }
      lPatchedBuffer.push(line);
    }
    this.lBuffer = lPatchedBuffer;
    this.lineNum = 0;
    // --- for handling #include
    this.altInput = undef;
    this.altLevel = undef; // indentation added to lines from alt
    this.checkBuffer("StringFetcher constructor end");
  }

  // ..........................................................
  checkBuffer(where = "unknown") {
    var j, len1, ref, str;
    ref = this.lBuffer;
    for (j = 0, len1 = ref.length; j < len1; j++) {
      str = ref[j];
      if (str === undef) {
        log(`undef value in lBuffer in ${where}`);
        croak("A string in lBuffer is undef");
      }
    }
  }

  // ..........................................................
  getIncludeFileDir(ext) {
    var envvar;
    // --- override to not use defaults
    envvar = hExtToEnvVar[ext];
    if (envvar != null) {
      return process.env[envvar];
    } else {
      return undef;
    }
  }

  // ..........................................................
  getIncludeFileFullPath(filename) {
    var base, dir, ext, incDir, path, root;
    ({root, dir, base, ext} = pathlib.parse(filename));
    assert(!dir, "getFileFullPath(): arg is not a simple file name");
    if (this.hSourceInfo.filename === 'unit test') {
      if (process.env.DIR_ROOT != null) {
        path = mkpath(process.env.DIR_ROOT, filename);
        if (fs.existsSync(path)) {
          return path;
        }
      }
    }
    if (this.hSourceInfo.dir != null) {
      path = mkpath(this.hSourceInfo.dir, filename);
      if (fs.existsSync(path)) {
        return path;
      }
    }
    incDir = this.getIncludeFileDir(ext);
    if (incDir != null) {
      assert(fs.existsSync(incDir), `dir ${incDir} does not exist`);
    }
    path = mkpath(incDir, filename);
    if (fs.existsSync(path)) {
      return path;
    }
    return undef;
  }

  // ..........................................................
  debugBuffer() {
    debug('BUFFER', this.lBuffer);
  }

  // ..........................................................
  fetch(literal = false) {
    var _, contents, fname, includePath, lMatches, line, prefix, result;
    // --- literal = true means don't handle #include,
    //               just return it as is
    debug(`enter fetch(literal=${literal}) from ${this.filename}`);
    this.checkBuffer("in fetch()");
    if (this.altInput) {
      assert(this.altLevel != null, "fetch(): alt input without alt level");
      line = this.altInput.fetch(literal);
      if (line != null) {
        result = indented(line, this.altLevel);
        debug(`return ${OL(result)} from fetch() - alt`);
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
    if (line === '__END__') {
      this.lBuffer = [];
      debug("return from fetch() - __END__ seen");
      return undef;
    }
    this.lineNum += 1;
    if (line === undef) {
      log("HERE IT IS: line is undef!!!");
      process.exit(-42);
    }
    if (!literal && (lMatches = line.match(/^(\s*)\#include\s+(\S.*)$/))) {
      [_, prefix, fname] = lMatches;
      fname = fname.trim();
      debug(`#include ${fname} with prefix ${OL(prefix)}`);
      assert(!this.altInput, "fetch(): altInput already set");
      includePath = this.getIncludeFileFullPath(fname);
      if (includePath == null) {
        croak(`Can't find include file ${fname} anywhere`);
      }
      contents = slurp(includePath);
      this.altInput = new StringFetcher(contents, fname);
      this.altLevel = indentLevel(prefix);
      debug(`alt input created with prefix ${OL(prefix)}`);
      line = this.altInput.fetch();
      debug(`first #include line found = '${escapeStr(line)}'`);
      this.altInput.debugBuffer();
      if (line != null) {
        result = indented(line, this.altLevel);
      } else {
        result = this.fetch(); // recursive call
      }
      debug(`return ${OL(result)} from fetch()`);
      return result;
    } else {
      debug(`return ${OL(line)} from fetch()`);
      return line;
    }
  }

  // ..........................................................
  // --- Put a line back into lBuffer, to be fetched later
  unfetch(line) {
    debug(`enter unfetch(${OL(line)})`);
    assert(isString(line), "unfetch(): not a string");
    if (this.altInput) {
      assert(line != null, "unfetch(): line is undef");
      this.altInput.unfetch(undented(line, this.altLevel));
    } else {
      this.lBuffer.unshift(line);
      this.lineNum -= 1;
    }
    debug('return from unfetch()');
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
    return arrayToBlock(lLines);
  }

};

// ===========================================================================
//   class StringInput
//      - keep track of indentation
//      - allow mapping of lines, including skipping lines
//      - implement look ahead via peek()
export var StringInput = class StringInput extends StringFetcher {
  constructor(content, source) {
    super(content, source);
    this.lookahead = undef; // --- lookahead token, placed by unget
    
    // --- cache in case getAll() is called multiple times
    //     each pair is [mapped str, level]
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
      debug("return undef from peek()");
      return undef;
    }
    this.unget(pair);
    debug(`return ${OL(pair)} from peek`);
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
    debug("enter StringInput.mapLine()");
    assert((line != null) && isString(line), "StringInput.mapLine(): not a string");
    debug(`return ${OL(line)}, ${level} from StringInput.mapLine()`);
    return line;
  }

  // ..........................................................
  get() {
    var level, line, result, saved, str;
    debug(`enter StringInput.get() - from ${this.filename}`);
    if (this.lookahead != null) {
      saved = this.lookahead;
      this.lookahead = undef;
      debug("return lookahead pair from StringInput.get()");
      return saved;
    }
    line = this.fetch(); // will handle #include
    debug("LINE", line);
    if (line == null) {
      debug("return undef from StringInput.get() at EOF");
      return undef;
    }
    [level, str] = splitLine(line);
    result = this.mapLine(str, level);
    debug(`MAP: '${str}' => ${OL(result)}`);
    while ((result == null) && (this.lBuffer.length > 0)) {
      line = this.fetch();
      [level, str] = splitLine(line);
      result = this.mapLine(str, level);
      debug(`MAP: '${str}' => ${OL(result)}`);
    }
    if (result != null) {
      debug(`return [${OL(result)}, ${level}] from StringInput.get()`);
      return [result, level];
    } else {
      debug("return undef from StringInput.get()");
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
      debug(`LINE IS ${OL(line)}`);
      assert(isString(line), `StringInput.fetchBlock(${atLevel}) - not a string: ${line}`);
      if (isEmpty(line)) {
        debug("empty line");
        lLines.push('');
        continue;
      }
      [level, str] = splitLine(line);
      debug(`LOOP: level = ${level}, str = ${OL(str)}`);
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
    debug("enter StringInput.getAll()");
    if (this.lAllPairs != null) {
      debug("return cached lAllPairs from StringInput.getAll()");
      return this.lAllPairs;
    }
    lPairs = [];
    while ((pair = this.get()) != null) {
      lPairs.push(pair);
    }
    this.lAllPairs = lPairs;
    debug("lAllPairs", this.lAllPairs);
    debug(`return ${lPairs.length} pairs from StringInput.getAll()`);
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
    return arrayToBlock(lLines);
  }

};

// ===========================================================================
export var SmartInput = class SmartInput extends StringInput {
  // - removes blank lines and comments (but can be overridden)
  // - joins continuation lines
  // - handles HEREDOCs
  constructor(content, source) {
    super(content, source);
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
    while (((nextLine = this.fetch(true)) != null) && (nonEmpty(nextLine)) && ([nextLevel, nextStr] = splitLine(nextLine)) && (nextLevel >= curlevel + 2)) {
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
    var contLine, j, lMatches, len1, n;
    for (j = 0, len1 = lContLines.length; j < len1; j++) {
      contLine = lContLines[j];
      if (lMatches = line.match(/\s*\\$/)) {
        n = lMatches[0].length;
        line = line.substr(0, line.length - n);
      }
      line += ' ' + contLine;
    }
    return line;
  }

  // ..........................................................
  handleEmptyLine(level) {
    debug("in SmartInput.handleEmptyLine()");
    return undef; // skip blank lines by default
  }

  
    // ..........................................................
  handleComment(line, level) {
    debug("in SmartInput.handleComment()");
    return undef; // skip comments by default
  }

  
    // ..........................................................
  // --- designed to override with a mapping method
  //     NOTE: line includes the indentation
  mapLine(line, level) {
    var lContLines, orgLineNum, result;
    debug(`enter SmartInput.mapLine(${OL(line)}, ${level})`);
    assert(line != null, "mapLine(): line is undef");
    assert(isString(line), `mapLine(): ${OL(line)} not a string`);
    if (isEmpty(line)) {
      debug("return undef from SmartInput.mapLine() - empty");
      return this.handleEmptyLine(this.curLevel);
    }
    if (isComment(line)) {
      debug("return undef from SmartInput.mapLine() - comment");
      return this.handleComment(line, level);
    }
    orgLineNum = this.lineNum;
    this.curLevel = level;
    // --- Merge in any continuation lines
    debug("check for continuation lines");
    lContLines = this.getContLines(level);
    if (isEmpty(lContLines)) {
      debug("no continuation lines found");
    } else {
      debug(`${lContLines.length} continuation lines found`);
      line = this.joinContLines(line, lContLines);
      debug(`line becomes ${OL(line)}`);
    }
    // --- handle HEREDOCs
    debug("check for HEREDOC");
    if (line.indexOf('<<<') !== -1) {
      line = this.handleHereDoc(line, level);
      debug(`line becomes ${OL(line)}`);
    }
    debug("mapping string");
    result = this.mapString(line, level);
    debug(`return ${OL(result)} from SmartInput.mapLine()`);
    return result;
  }

  // ..........................................................
  mapString(line, level) {
    // --- NOTE: line has indentation removed
    //     when overriding, may return anything
    //     return undef to generate nothing
    assert(isString(line), `default mapString(): ${OL(line)} is not a string`);
    return line;
  }

  // ..........................................................
  handleHereDoc(line, level) {
    var lLines, lParts, newstr, part, pos, result, start;
    // --- Indentation is removed from line
    // --- Find each '<<<' and replace with result of mapHereDoc()
    assert(isString(line), "handleHereDoc(): not a string");
    debug(`enter handleHereDoc(${OL(line)})`);
    lParts = []; // joined at the end
    pos = 0;
    while ((start = line.indexOf('<<<', pos)) !== -1) {
      part = line.substring(pos, start);
      debug(`PUSH ${OL(part)}`);
      lParts.push(part);
      lLines = this.getHereDocLines(level + 1);
      assert(isArray(lLines), "handleHereDoc(): lLines not an array");
      debug(`HEREDOC lines: ${OL(lLines)}`);
      newstr = mapHereDoc(arrayToBlock(lLines));
      assert(isString(newstr), "handleHereDoc(): newstr not a string");
      debug(`PUSH ${OL(newstr)}`);
      lParts.push(newstr);
      pos = start + 3;
    }
    // --- If no '<<<' in string, just return original line
    if (pos === 0) {
      debug("return from handleHereDoc - no <<< in line");
      return line;
    }
    assert(line.indexOf('<<<', pos) === -1, "handleHereDoc(): Not all HEREDOC markers were replaced" + `in '${line}'`);
    part = line.substring(pos, line.length);
    debug(`PUSH ${OL(part)}`);
    lParts.push(part);
    result = lParts.join('');
    debug("return from handleHereDoc", result);
    return result;
  }

  // ..........................................................
  getHereDocLines(atLevel) {
    var lLines, line, newline;
    // --- Get all lines until addHereDocLine() returns undef
    //     atLevel will be one greater than the indent
    //        of the line containing <<<

    // --- NOTE: splitLine() removes trailing whitespace
    debug("enter SmartInput.getHereDocLines()");
    lLines = [];
    while (((line = this.fetch()) != null) && ((newline = this.hereDocLine(undented(line, atLevel))) != null)) {
      assert(indentLevel(line) >= atLevel, "invalid indentation in HEREDOC section");
      lLines.push(newline);
    }
    assert(isArray(lLines), "getHereDocLines(): retval not an array");
    debug("return from SmartInput.getHereDocLines()", lLines);
    return lLines;
  }

  // ..........................................................
  hereDocLine(line) {
    if (isEmpty(line)) {
      return undef; // end the HEREDOC section
    } else if (line === '.') {
      return ''; // interpret '.' as blank line
    } else {
      return line;
    }
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
  constructor(content, source) {
    super(content, source);
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
// Utility function to get a tree from text,
//    given a function to map a string (to anything!)
export var treeFromBlock = function(block, mapFunc) {
  var MyPLLParser, parser;
  MyPLLParser = class MyPLLParser extends PLLParser {
    mapNode(line, level) {
      assert(isString(line), "StringInput.mapNode(): not a string");
      return mapFunc(line, level);
    }

  };
  parser = new MyPLLParser(block);
  return parser.getTree();
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
export var getFileContents = function(fname, convert = false, dir = undef) {
  var base, contents, envvar, ext, fullpath, path, root;
  fname = fname.trim();
  debug(`enter getFileContents('${fname}')`);
  assert(isString(fname), "getFileContents(): fname not a string");
  ({root, dir, base, ext} = pathlib.parse(fname));
  assert(!root && !dir, "getFileContents():" + ` root='${root}', dir='${dir}'` + " - full path not allowed");
  if (dir) {
    path = mkpath(dir, fname);
    if (fs.existsSync(path)) {
      return slurp(path);
    }
  }
  envvar = hExtToEnvVar[ext];
  debug(`envvar = '${envvar}'`);
  assert(envvar, `getFileContents() doesn't work for ext '${ext}'`);
  dir = process.env[envvar];
  debug(`dir = '${dir}'`);
  if (dir == null) {
    croak(`env var '${envvar}' not set for file extension '${ext}'`, 'process.env', process.env);
  }
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
