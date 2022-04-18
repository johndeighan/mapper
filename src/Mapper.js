// Generated by CoffeeScript 2.6.1
// Mapper.coffee
import fs from 'fs';

import pathlib from 'path';

import {
  assert,
  error,
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
  CWS,
  replaceVars
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
  mkpath,
  isDir
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
  lineToParts,
  mapHereDoc
} from '@jdeighan/mapper/heredoc';

// ---------------------------------------------------------------------------
//   class StringFetcher - stream in lines from a string
//       handles:
//          __END__
//          #include
export var StringFetcher = class StringFetcher {
  constructor(content, source = undef) {
    if (isEmpty(source)) {
      this.setContent(content, 'unit test');
    } else {
      this.setContent(content, source);
    }
    // --- for handling #include
    this.altInput = undef;
    this.altLevel = undef; // indentation added to lines from alt
    this.checkBuffer("StringFetcher constructor end");
  }

  // ..........................................................
  setContent(content, source) {
    debug("enter setContent()", content);
    // --- @hSourceInfo has keys: dir, filename, stub, ext, fullpath
    //     If source is 'unit test', just has:
    //     { filename: 'unit test', stub: 'unit test'}
    this.hSourceInfo = parseSource(source);
    this.filename = this.hSourceInfo.filename;
    assert(this.filename, "StringFetcher: parseSource returned no filename");
    if (content == null) {
      if (this.hSourceInfo.fullpath) {
        content = slurp(this.hSourceInfo.fullpath);
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
      croak("StringFetcher(): content must be a string", "CONTENT", content);
    }
    this.lineNum = 0;
    debug("return from setContent()", this.lBuffer);
  }

  // ..........................................................
  checkBuffer(where = "unknown") {
    var i, len, ref, str;
    ref = this.lBuffer;
    for (i = 0, len = ref.length; i < len; i++) {
      str = ref[i];
      if (str === undef) {
        log(`undef value in lBuffer in ${where}`);
        croak("A string in lBuffer is undef");
      } else if (str.match(/\r/)) {
        log("string has a carriage return");
        croak("A string in lBuffer has a carriage return");
      } else if (str.match(/\n/)) {
        log("string has newline");
        croak("A string in lBuffer has a newline");
      }
    }
  }

  // ..........................................................
  getIncludeFileFullPath(fname) {
    var base, dir, ext, path, root;
    debug(`enter getIncludeFileFullPath('${fname}')`);
    // --- Make sure we have a simple file name
    ({root, dir, base, ext} = pathlib.parse(fname));
    assert(!dir, "getIncludeFileFullPath(): not a simple file name");
    // --- Decide which directory to search for file
    dir = this.hSourceInfo.dir;
    if (!dir || !isDir(dir)) {
      // --- Use current directory
      dir = process.cwd();
    }
    path = pathTo(fname, dir);
    debug("path", path);
    if (path) {
      assert(fs.existsSync(path), "path does not exist");
      debug("return from getIncludeFileFullPath()");
      return path;
    } else {
      debug("return from getIncludeFileFullPath() - file not found");
      return undef;
    }
  }

  // ..........................................................
  debugBuffer() {
    debug('BUFFER', this.lBuffer);
  }

  // ..........................................................
  // --- Can override to add additional functionality
  incLineNum(inc) {
    this.lineNum += inc;
  }

  // ..........................................................
  fetch(literal = false) {
    var _, contents, fname, includePath, lMatches, line, prefix, result;
    // --- literal = true means don't handle #include,
    //               just return it as is
    debug(`enter fetch(literal=${literal}) from ${this.filename}`);
    // --- @checkBuffer "in fetch()"
    if (this.altInput) {
      assert(this.altLevel != null, "fetch(): alt input without alt level");
      line = this.altInput.fetch(literal);
      if (line != null) {
        result = indented(line, this.altLevel);
        this.incLineNum(1);
        debug(`return ${OL(result)} from fetch() - alt`);
        return result;
      } else {
        // alternate input is exhausted
        this.altInput = undef;
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
    this.incLineNum(1);
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
      this.incLineNum(-1);
    }
    debug('return from unfetch()');
  }

  // ..........................................................
  getBlock() {
    var block, lLines, line;
    debug("enter getBlock()");
    lLines = (function() {
      var results;
      results = [];
      while (line = this.fetch()) {
        assert(isString(line), `getBlock(): got non-string '${OL(line)}'`);
        results.push(line);
      }
      return results;
    }).call(this);
    block = arrayToBlock(lLines);
    debug("return from getBlock()", block);
    return block;
  }

};

// ===========================================================================
//   class Mapper
//      - keep track of indentation
//      - allow mapping of lines, including skipping lines
//      - implement look ahead via peek()
export var Mapper = class Mapper extends StringFetcher {
  constructor(content, source) {
    super(content, source);
    this.lookahead = undef; // --- lookahead token, placed by unget
    
    // --- cache in case getAll() is called multiple times
    //     each pair is [<mapped str>, <level>]
    this.lAllPairs = undef;
  }

  // ..........................................................
  unget(lPair) {
    // --- lPair will always be [<item>, <level>]
    //     <item> can be anything - i.e. it's been mapped
    debug('enter unget() with', lPair);
    assert(this.lookahead == null, "unget(): there's already a lookahead");
    this.lookahead = lPair;
    debug('return from unget()');
  }

  // ..........................................................
  peek() {
    var lPair;
    debug('enter peek():');
    if (this.lookahead != null) {
      debug("return lookahead from peek");
      return this.lookahead;
    }
    lPair = this.get();
    if (lPair == null) {
      debug("return undef from peek()");
      return undef;
    }
    this.unget(lPair);
    debug(`return ${OL(lPair)} from peek`);
    return lPair;
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
    debug("enter Mapper.mapLine()");
    assert((line != null) && isString(line), "Mapper.mapLine(): not a string");
    debug(`return ${OL(line)}, ${level} from Mapper.mapLine()`);
    return line;
  }

  // ..........................................................
  get() {
    var level, line, result, saved, str;
    debug(`enter Mapper.get() - from ${this.filename}`);
    if (this.lookahead != null) {
      saved = this.lookahead;
      this.lookahead = undef;
      debug("return lookahead pair from Mapper.get()");
      return saved;
    }
    line = this.fetch(); // will handle #include
    debug("LINE", line);
    if (line == null) {
      debug("return undef from Mapper.get() at EOF");
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
      debug(`return [${OL(result)}, ${level}] from Mapper.get()`);
      return [result, level];
    } else {
      debug("return undef from Mapper.get()");
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
      assert(isString(line), `Mapper.fetchBlock(${atLevel}) - not a string: ${line}`);
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
    var lPair, lPairs;
    debug("enter Mapper.getAll()");
    if (this.lAllPairs != null) {
      debug("return cached lAllPairs from Mapper.getAll()");
      return this.lAllPairs;
    }
    lPairs = [];
    // --- Each pair is [<result>, <level>],
    //     where <result> can be anything
    while ((lPair = this.get()) != null) {
      lPairs.push(lPair);
    }
    this.lAllPairs = lPairs;
    debug("lAllPairs", this.lAllPairs);
    debug(`return ${lPairs.length} pairs from Mapper.getAll()`);
    return lPairs;
  }

  // ..........................................................
  getBlock() {
    var lLines, level, line;
    lLines = (function() {
      var i, len, ref, results;
      ref = this.getAll();
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        [line, level] = ref[i];
        assert(isString(line), "getBlock(): got non-string");
        results.push(indented(line, level));
      }
      return results;
    }).call(this);
    return arrayToBlock(lLines);
  }

};

// ===========================================================================
export var stdSplitCommand = function(line, level) {
  var _, argstr, cmd, lMatches;
  if (lMatches = line.match(/^\#([A-Za-z_]\w*)\s*(.*)$/)) { // name of the command
    // argstr for command
    [_, cmd, argstr] = lMatches;
    return [cmd, argstr];
  } else {
    return undef; // not a command
  }
};


// ---------------------------------------------------------------------------
export var stdIsComment = function(line, level) {
  var _, ch, hashes, lMatches;
  lMatches = line.match(/^(\#+)(.|$)/); // one or more # characters
  // following character, if any
  if (lMatches) {
    [_, hashes, ch] = lMatches;
    return (hashes.length > 1) || (ch === ' ' || ch === '\t' || ch === '');
  } else {
    return false;
  }
};

// ---------------------------------------------------------------------------
export var CieloMapper = class CieloMapper extends Mapper {
  // - removes blank lines (but can be overridden)
  // - does NOT remove comments (but can be overridden)
  // - joins continuation lines
  // - handles HEREDOCs
  // - handles #define <name> <value> and __<name>__ substitution
  constructor(content, source) {
    super(content, source);
    debug(`enter CieloMapper(source='${source}')`, content);
    this.hVars = {
      FILE: this.filename,
      DIR: this.hSourceInfo.dir,
      LINE: 0
    };
    // --- This should only be used in mapLine(), where
    //     it keeps track of the level we're at, to be passed
    //     to handleEmptyLine() since the empty line itself
    //     is always at level 0
    this.curLevel = 0;
    debug("return from CieloMapper()");
  }

  // ..........................................................
  // --- designed to override with a mapping method
  //     NOTE: line does not include the indentation
  mapLine(line, level) {
    var cmd, hResult, lContLines, lParts, longline, orgLineNum, replaced, result, tail, verylongline;
    debug(`enter CieloMapper.mapLine(${OL(line)}, ${level})`);
    assert(line != null, "mapLine(): line is undef");
    assert(isString(line), `mapLine(): ${OL(line)} not a string`);
    if (isEmpty(line)) {
      result = this.handleEmptyLine(this.curLevel);
      debug(`return ${OL(result)} from CieloMapper.mapLine() - empty line`);
      return result;
    }
    debug("line is not empty, checking for command");
    lParts = this.splitCommand(line);
    if (lParts) {
      debug("found command", lParts);
      [cmd, tail] = lParts;
      result = this.handleCommand(cmd, tail, level);
      debug(`return ${OL(result)} from CieloMapper.mapLine() - command handled`);
      return result;
    }
    if (isComment(line)) {
      result = this.handleComment(line, level);
      debug(`return ${OL(result)} from CieloMapper.mapLine() - comment`);
      return result;
    }
    debug("hVars", this.hVars);
    replaced = replaceVars(line, this.hVars);
    if (replaced !== line) {
      debug("replaced", replaced);
    }
    orgLineNum = this.lineNum;
    this.curLevel = level;
    // --- Merge in any continuation lines
    debug("check for continuation lines");
    lContLines = this.getContLines(level);
    if (isEmpty(lContLines)) {
      debug("no continuation lines found");
      longline = replaced;
    } else {
      debug(`${lContLines.length} continuation lines found`);
      longline = this.joinContLines(replaced, lContLines);
      debug(`line becomes ${OL(longline)}`);
    }
    // --- handle HEREDOCs
    debug("check for HEREDOC");
    if (line.indexOf('<<<') === -1) {
      verylongline = longline;
    } else {
      hResult = this.handleHereDoc(longline, level);
      verylongline = hResult.line;
      debug(`line becomes ${OL(verylongline)}`);
    }
    debug("mapping string");
    result = this.mapString(verylongline, level);
    debug(`return ${OL(result)} from CieloMapper.mapLine()`);
    return result;
  }

  // ..........................................................
  handleEmptyLine(level) {
    debug("in CieloMapper.handleEmptyLine()");
    // --- remove blank lines by default
    //     return '' to retain empty lines
    return undef;
  }

  // ..........................................................
  splitCommand(line, level) {
    var _, argstr, cmd, lMatches, lResult;
    debug("enter CieloMapper.splitCommand()");
    if (lMatches = line.match(/^\#([A-Za-z_]\w*)\s*(.*)$/)) { // name of the command
      // argstr for command
      [_, cmd, argstr] = lMatches;
      lResult = [cmd, argstr];
      debug("return from CieloMapper.splitCommand()", lResult);
      return lResult;
    } else {
      // --- not a command
      debug("return undef from CieloMapper.splitCommand()");
      return undef;
    }
  }

  // ..........................................................
  handleCommand(cmd, argstr, level) {
    var _, lMatches, name, prefix, tail;
    debug(`enter handleCommand ${cmd} '${argstr}', ${level}`);
    switch (cmd) {
      case 'define':
        if (lMatches = argstr.match(/^(env\.)?([A-Za-z_][\w\.]*)(.*)$/)) { // name of the variable
          [_, prefix, name, tail] = lMatches;
          tail = tail.trim();
          if (prefix) {
            debug(`set env var ${name} to '${tail}'`);
            process.env[name] = tail;
          } else {
            debug(`set var ${name} to '${tail}'`);
            this.setVariable(name, tail);
          }
        }
    }
    debug("return undef from handleCommand()");
    return undef; // return value added to output if not undef
  }

  
    // ..........................................................
  setVariable(name, value) {
    debug(`enter setVariable('${name}')`, value);
    assert(isString(name), "name is not a string");
    assert(isString(value), "value is not a string");
    assert((name !== 'DIR' && name !== 'FILE' && name !== 'LINE' && name !== 'END'), `Bad var name '${name}'`);
    this.hVars[name] = value;
    debug("return from setVariable()");
  }

  // ..........................................................
  // --- override to keep variable LINE updated
  incLineNum(inc) {
    super.incLineNum(inc); // adjusts property @lineNum
    this.hVars.LINE = this.lineNum;
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
    var contLine, i, lMatches, len, n;
    for (i = 0, len = lContLines.length; i < len; i++) {
      contLine = lContLines[i];
      if (lMatches = line.match(/\s*\\$/)) {
        n = lMatches[0].length;
        line = line.substr(0, line.length - n);
      }
      line += ' ' + contLine;
    }
    return line;
  }

  // ..........................................................
  isComment(line, level) {
    debug("in CieloMapper.isComment()");
    return stdIsComment(line, level);
  }

  // ..........................................................
  handleComment(line, level) {
    debug("in CieloMapper.handleComment()");
    return line; // keep comments by default
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
  mapHereDoc(block) {
    var hResult;
    // --- A method you can override
    //     Distinct from the mapHereDoc() function found in /heredoc
    hResult = mapHereDoc(block);
    assert(isHash(hResult), "mapHereDoc(): hResult not a hash");
    return hResult;
  }

  // ..........................................................
  handleHereDoc(line, level) {
    var hResult, lLines, lNewParts, lObjects, lParts, part;
    // --- Indentation has been removed from line
    // --- Find each '<<<' and replace with result of mapHereDoc()
    assert(isString(line), "handleHereDoc(): not a string");
    debug(`enter handleHereDoc(${OL(line)})`);
    lParts = lineToParts(line);
    lObjects = [];
    lNewParts = (function() {
      var i, len, results;
      results = [];
      for (i = 0, len = lParts.length; i < len; i++) {
        part = lParts[i];
        if (part === '<<<') {
          lLines = this.getHereDocLines(level + 1);
          hResult = this.mapHereDoc(arrayToBlock(lLines));
          lObjects.push(hResult.obj);
          results.push(hResult.str);
        } else {
          results.push(part); // keep as is
        }
      }
      return results;
    }).call(this);
    hResult = {
      line: lNewParts.join(''),
      lParts: lParts,
      lObjects: lObjects
    };
    debug("return from handleHereDoc", hResult);
    return hResult;
  }

  // ..........................................................
  getHereDocLines(atLevel) {
    var lLines, line, newline;
    // --- Get all lines until addHereDocLine() returns undef
    //     atLevel will be one greater than the indent
    //        of the line containing <<<

    // --- NOTE: splitLine() removes trailing whitespace
    debug("enter CieloMapper.getHereDocLines()");
    lLines = [];
    while (((line = this.fetch()) != null) && ((newline = this.hereDocLine(undented(line, atLevel))) != null)) {
      assert(indentLevel(line) >= atLevel, "invalid indentation in HEREDOC section");
      lLines.push(newline);
    }
    assert(isArray(lLines), "getHereDocLines(): retval not an array");
    debug("return from CieloMapper.getHereDocLines()", lLines);
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

// ===========================================================================
export var doMap = function(inputClass, text, source = 'unit test') {
  var className, lMatches, oInput, result;
  if (lMatches = inputClass.toString().match(/class\s+(\w+)/)) {
    className = lMatches[1];
  } else {
    className = 'unknown';
  }
  debug(`enter doMap(${className}) source='${source}'`);
  if (inputClass) {
    oInput = new inputClass(text, source);
    assert(oInput instanceof Mapper, "doMap() requires a Mapper or subclass");
  } else {
    oInput = new CieloMapper(text, source);
  }
  result = oInput.getBlock();
  debug("return from doMap()", result);
  return result;
};
