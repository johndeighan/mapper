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
  unitTesting,
  oneline
} from '@jdeighan/coffee-utils';

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
//   class StringInput - stream in lines from a string or array
export var StringInput = class StringInput {
  // --- handles #include statements
  constructor(content, hOptions1 = {}) {
    var base, filename;
    this.hOptions = hOptions1;
    // --- Valid options:
    //        filename
    ({filename} = this.hOptions);
    if (isEmpty(content)) {
      this.lBuffer = [];
    } else if (isString(content)) {
      this.lBuffer = stringToArray(content);
    } else if (isArray(content)) {
      // -- make a deep copy
      this.lBuffer = deepCopy(content);
    } else {
      croak("StringInput(): content must be array or string", "CONTENT", content);
    }
    this.lineNum = 0;
    debug("BUFFER", this.lBuffer);
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
    this.lookahead = undef; // lookahead token, placed by unget
    this.altInput = undef;
    this.altLevel = undef; // controls prefix prepended to lines
  }

  
    // ..........................................................
  unget(item) {
    // --- item has already been mapped
    debug('enter unget() with', item);
    assert(this.lookahead == null);
    this.lookahead = item;
    debug('return from unget()');
  }

  // ..........................................................
  peek() {
    var item;
    debug('enter peek():');
    if (this.lookahead != null) {
      debug("return lookahead token from peek");
      return this.lookahead;
    }
    item = this.get();
    if (item == null) {
      debug("return from peek() - undef");
      return undef;
    }
    this.unget(item);
    debug(`return ${oneline(item)} from peek`);
    return item;
  }

  // ..........................................................
  skip() {
    debug('enter skip():');
    if (this.lookahead != null) {
      this.lookahead = undef;
      debug("return from skip: clear lookahead token");
      return;
    }
    this.get();
    debug('return from skip()');
  }

  // ..........................................................
  // --- Returns undef if either:
  //        1. there's no alt input
  //        2. get from alt input returns undef (then closes alt input)
  getFromAlt() {
    var result;
    debug("enter getFromAlt()");
    if (!this.altInput) {
      croak("getFromAlt(): There is no alt input");
    }
    result = this.altInput.get();
    if (result != null) {
      debug(`return ${oneline(result)} from getFromAlt`);
      return indented(result, this.altLevel);
    } else {
      this.altInput = undef;
      this.altLevel = undef;
      debug("return from getFromAlt: alt returned undef, alt input removed");
      return undef;
    }
  }

  // ..........................................................
  // --- Returns undef if either:
  //        1. there's no alt input
  //        2. get from alt input returns undef (then closes alt input)
  fetchFromAlt() {
    var result;
    debug("enter fetchFromAlt()");
    if (!this.altInput) {
      croak("fetchFromAlt(): There is no alt input");
    }
    result = this.altInput.fetch();
    if (result != null) {
      `return ${oneline(result)} from getFromAlt()`;
      return indented(result, this.altLevel);
    } else {
      debug("return from fetchFromAlt: alt returned undef, alt input removed");
      this.altInput = undef;
      this.altLevel = undef;
      return undef;
    }
  }

  // ..........................................................
  // --- designed to override with a mapping method
  //     NOTE: line includes the indentation
  mapLine(line) {
    debug(`in default mapLine(${oneline(line)})`);
    return line;
  }

  // ..........................................................
  get() {
    var line, result, saved;
    debug(`enter get() - src ${this.filename}`);
    if (this.lookahead != null) {
      saved = this.lookahead;
      this.lookahead = undef;
      debug(`return lookahead token from get() - src ${this.filename}`);
      return saved;
    }
    if (this.altInput && ((line = this.getFromAlt()) != null)) {
      debug(`return from get() with ${oneline(line)} - from alt ${this.filename}`);
      return line;
    }
    line = this.fetch(); // will handle #include
    debug("LINE", line);
    if (line == null) {
      debug(`return from get() with undef at EOF - src ${this.filename}`);
      return undef;
    }
    result = this.mapLine(line);
    debug(`MAP: '${line}' => ${oneline(result)}`);
    // --- if mapLine() returns undef, we skip that line
    while ((result == null) && (this.lBuffer.length > 0)) {
      line = this.fetch();
      result = this.mapLine(line);
      debug(`'${line}' mapped to '${result}'`);
    }
    debug(`return ${oneline(result)} from get() - src ${this.filename}`);
    return result;
  }

  // ..........................................................
  // --- This should be used to fetch from @lBuffer
  //     to maintain proper @lineNum for error messages
  //     MUST handle #include
  fetch() {
    var _, altLine, contents, fname, lMatches, level, line, result, str;
    debug("enter fetch()");
    if (this.altInput && ((result = this.fetchFromAlt()) != null)) {
      debug(`return alt ${oneline(result)} from fetch()`);
      return result;
    }
    if (this.lBuffer.length === 0) {
      debug("return from fetch() - empty buffer, return undef");
      return undef;
    }
    this.lineNum += 1;
    line = this.lBuffer.shift();
    [level, str] = splitLine(line);
    if (lMatches = str.match(/^\#include\s+(\S.*)$/)) {
      [_, fname] = lMatches;
      assert(!this.altInput, "fetch(): altInput already set");
      if (unitTesting) {
        debug(`return from fetch() 'Contents of ${fname}' - unit testing`);
        return indented(`Contents of ${fname}`, level);
      }
      contents = getFileContents(fname);
      this.altInput = new StringInput(contents);
      this.altLevel = level;
      debug(`alt input created at level ${level}`);
      // --- We just created an alt input
      //     we need to get its first line
      altLine = this.getFromAlt();
      if (altLine != null) {
        debug(`fetch(): getFromAlt returned '${altLine}'`);
        line = altLine;
      } else {
        debug(`fetch(): alt was undef, retain line '${line}'`);
      }
    }
    debug(`return from fetch() ${oneline(line)} from buffer:`);
    return line;
  }

  // ..........................................................
  // --- Put one or more lines back into lBuffer, to be fetched later
  unfetch(str) {
    debug("enter unfetch()", str);
    this.lBuffer.unshift(str);
    this.lineNum -= 1;
    debug('return from unfetch()');
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
    var lLines, line;
    debug("enter getAll()");
    lLines = [];
    line = this.get();
    while (line != null) {
      lLines.push(line);
      line = this.get();
    }
    debug(`return ${lLines.length} lines from getAll()`);
    return lLines;
  }

  // ..........................................................
  skipAll() {
    var line;
    // --- Useful if you don't need the final output, but, e.g.
    //     mapString() builds something that you will fetch
    line = this.get();
    while (line != null) {
      line = this.get();
    }
  }

  // ..........................................................
  getAllText() {
    return arrayToString(this.getAll());
  }

};

// ===========================================================================
export var SmartInput = class SmartInput extends StringInput {
  // - removes blank lines and comments
  // - joins continuation lines
  // - handles HEREDOCs
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
  handleEmptyLine() {
    debug("in default handleEmptyLine()");
    return undef; // skip blank lines by default
  }

  
    // ..........................................................
  handleComment() {
    debug("in default handleComment()");
    return undef; // skip comments by default
  }

  
    // ..........................................................
  // --- designed to override with a mapping method
  //     NOTE: line includes the indentation
  mapLine(orgLine) {
    var lContLines, level, line, orgLineNum, result;
    debug(`enter mapLine(${oneline(orgLine)})`);
    assert(orgLine != null, "mapLine(): orgLine is undef");
    if (isEmpty(orgLine)) {
      debug("return undef from mapLine() - empty");
      return this.handleEmptyLine();
    }
    if (isComment(orgLine)) {
      debug("return undef from mapLine() - comment");
      return this.handleComment();
    }
    [level, line] = splitLine(orgLine);
    orgLineNum = this.lineNum;
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
  handleHereDoc(line, level) {
    var blk, lLines, lParts, newstr, part, pos, result, start;
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
        blk = arrayToString(undented(lLines));
        if (isTAML(blk)) {
          result = taml(blk);
          newstr = JSON.stringify(result);
        } else {
          newstr = this.heredocStr(blk);
        }
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
  heredocStr(str) {
    // --- return replacement string for '<<<'
    return str.replace(/\n/sg, ' ');
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
/*

WHEN NOT UNIT TESTING

- converts
		<varname> <== <expr>

	to:
		`$:`
		<varname> = <expr>

	coffeescript to:
		var <varname>;
		$:;
		<varname> = <js expr>;

	brewCoffee() to:
		var <varname>;
		$:
		<varname> = <js expr>;

- converts
		<==
			<code>

	to:
		`$:{`
		<code>
		`}`

	coffeescript to:
		$:{;
		<js code>
		};

	brewCoffee() to:
		$:{
		<js code>
		}

*/
// ===========================================================================
export var CoffeeMapper = class CoffeeMapper extends SmartInput {
  mapString(line, level) {
    var _, code, expr, lMatches, result, varname;
    debug(`enter mapString(${oneline(line)})`);
    if (line === '<==') {
      // --- Generate a reactive block
      code = this.fetchBlock(level + 1); // might be empty
      if (isEmpty(code)) {
        debug("return undef from mapString() - empty code block");
        return undef;
      } else {
        result = `\`$:{\`
${code}
\`}\``;
      }
    } else if (lMatches = line.match(/^([A-Za-z][A-Za-z0-9_]*)\s*\<\=\=\s*(.*)$/)) { // variable name
      [_, varname, expr] = lMatches;
      code = this.fetchBlock(level + 1); // must be empty
      assert(isEmpty(code), `mapLine(): indented code not allowed after '${line}'`);
      assert(!isEmpty(expr), `mapLine(): empty expression in '${line}'`);
      result = `\`$:\`
${varname} = ${expr}`;
    } else {
      debug("return from mapLine() - no match");
      return indented(line, level);
    }
    debug("return from mapLine()", result);
    return indented(result, level);
  }

};

// ---------------------------------------------------------------------------
export var CoffeePostMapper = class CoffeePostMapper extends StringInput {
  // --- variable declaration immediately following one of:
  //        $:{;
  //        $:;
  //     should be moved above this line
  mapLine(line) {
    var _, brace, lMatches, rest, result, ws;
    if (this.savedLine) {
      if (line.match(/^\s*var\s/)) {
        result = `${line}\n${this.savedLine}`;
      } else {
        result = `${this.savedLine}\n${line}`;
      }
      this.savedLine = undef;
      return result;
    }
    if ((lMatches = line.match(/^(\s*)\$\:(\{)?\;(.*)$/))) { // possible leading whitespace
      // optional {
      // any remaining text
      [_, ws, brace, rest] = lMatches;
      assert(!rest, "CoffeePostMapper: extra text after $:");
      if (brace) {
        this.savedLine = `${ws}$:{`;
      } else {
        this.savedLine = `${ws}$:`;
      }
      return undef;
    } else if ((lMatches = line.match(/^(\s*)\}\;(.*)$/))) { // possible leading whitespace
      [_, ws, rest] = lMatches;
      assert(!rest, "CoffeePostMapper: extra text after $:");
      return `${ws}\}`;
    } else {
      return line;
    }
  }

};

// ---------------------------------------------------------------------------
export var SassMapper = class SassMapper extends StringInput {
  // --- only removes comments
  mapLine(line) {
    if (isComment(line)) {
      return undef;
    }
    return line;
  }

};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
//   class FileInput - contents from a file
export var FileInput = class FileInput extends SmartInput {
  constructor(filename, hOptions = {}) {
    var base, content, dir, ext, root;
    ({root, dir, base, ext} = pathlib.parse(filename.trim()));
    hOptions.filename = base;
    if (unitTesting) {
      content = `Contents of ${base}`;
    } else {
      if (!fs.existsSync(filename)) {
        croak(`FileInput(): file '${filename}' does not exist`);
      }
      content = slurp(filename);
    }
    super(content, hOptions);
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
  mapString(line, level) {
    return [level, this.lineNum, this.mapNode(line)];
  }

  // ..........................................................
  mapNode(line) {
    return line;
  }

  // ..........................................................
  getTree() {
    var lLines, tree;
    debug("enter getTree()");
    lLines = this.getAll();
    debug(`lLines = ${oneline(lLines)}`);
    assert(lLines != null, "lLines is undef");
    assert(isArray(lLines), "getTree(): lLines is not an array");
    tree = treeify(lLines);
    debug("return from getTree()", tree);
    return tree;
  }

};

// ---------------------------------------------------------------------------
// Each item must be a sub-array with 3 items: [<level>, <lineNum>, <node>]
// If a predicate is supplied, it must return true for any <node>
export var treeify = function(lItems, atLevel = 0, predicate = undef) {
  var body, err, h, item, lNodes, len, level, lineNum, node;
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
    len = item.length;
    [level, lineNum, node] = item;
    assert(level === atLevel, `treeify(): item at level ${level}, should be ${atLevel}`);
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
  if (unitTesting) {
    debug("return from getFileContents() - unit testing");
    return `Contents of ${fname}`;
  }
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
