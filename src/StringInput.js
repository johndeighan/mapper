// Generated by CoffeeScript 2.5.1
// StringInput.coffee
var hasProp = {}.hasOwnProperty;

import {
  strict as assert
} from 'assert';

import fs from 'fs';

import pathlib from 'path';

import {
  undef,
  deepCopy,
  stringToArray,
  say,
  pass,
  debug,
  error,
  sep_dash,
  isString,
  unitTesting
} from '@jdeighan/coffee-utils';

import {
  slurp
} from '@jdeighan/coffee-utils/fs';

import {
  splitLine,
  indentedStr,
  indentation
} from '@jdeighan/coffee-utils/indent';

// ---------------------------------------------------------------------------
//   class StringInput - stream in lines from a string or array
export var StringInput = class StringInput {
  constructor(content, hOptions1 = {}) {
    var base, dir, ext, filename, hIncludePaths, prefix, ref;
    this.hOptions = hOptions1;
    // --- Valid options:
    //        filename
    //        prefix       # prepended to each defined retval from _mapped()
    //        hIncludePaths    { <ext>: <dir>, ... }
    ({filename, prefix, hIncludePaths} = this.hOptions);
    if (isString(content)) {
      this.lBuffer = stringToArray(content);
    } else if (isArray(content)) {
      // -- make a deep copy
      this.lBuffer = deepCopy(content);
    } else {
      error("StringInput(): content must be array or string");
    }
    this.lineNum = 0;
    if (filename) {
      try {
        // --- We only want the bare filename
        ({base} = pathlib.parse(filename));
        this.filename = base;
      } catch (error1) {
        this.filename = filename;
      }
    } else {
      this.filename = 'unit test';
    }
    this.prefix = prefix || '';
    this.hIncludePaths = this.hOptions.hIncludePaths || {};
    if (!unitTesting) {
      ref = this.hIncludePaths;
      for (ext in ref) {
        if (!hasProp.call(ref, ext)) continue;
        dir = ref[ext];
        assert(ext.indexOf('.') === 0, "invalid key in hIncludePaths");
        assert(fs.existsSync(dir), `dir ${dir} does not exist`);
      }
    }
    this.lookahead = undef; // lookahead token, placed by unget
    this.altInput = undef;
  }

  // ........................................................................
  mapLine(line) {
    return line;
  }

  // ........................................................................
  unget(item) {
    debug('UNGET:');
    assert(this.lookahead == null);
    debug(item, "Lookahead:");
    return this.lookahead = item;
  }

  // ........................................................................
  peek() {
    var item;
    debug('PEEK:');
    if (this.lookahead != null) {
      debug("   return lookahead token");
      return this.lookahead;
    }
    item = this.get();
    this.unget(item);
    return item;
  }

  // ........................................................................
  skip() {
    debug('SKIP:');
    if (this.lookahead != null) {
      debug("   undef lookahead token");
      this.lookahead = undef;
      return;
    }
    this.get();
  }

  // ........................................................................
  // --- returns [dir, base] if a valid #include
  checkForInclude(str) {
    var _, base, dir, ext, filename, fname, lMatches, root;
    assert(!str.match(/^\s/), "checkForInclude(): string has indentation");
    if (lMatches = str.match(/^\#include\s+(\S.*)$/)) {
      [_, fname] = lMatches;
      filename = fname.trim();
      ({root, dir, base, ext} = pathlib.parse(filename));
      if (!root && !dir && this.hIncludePaths && (dir = this.hIncludePaths[ext])) {
        assert(base === filename, `base = ${base}, filename = ${filename}`);
        // --- It's a plain file name with an extension
        //     that we can handle
        return [dir, base];
      }
    }
    return undef;
  }

  // ........................................................................
  // --- Returns undef if either:
  //        1. there's no alt input
  //        2. get from alt input returns undef (then closes alt input)
  getFromAlt() {
    var result;
    if (!this.altInput) {
      return undef;
    }
    result = this.altInput.get();
    if (result == null) {
      debug("   alt input removed");
      this.altInput = undef;
    }
    return result;
  }

  // ........................................................................
  get() {
    var line, result, save;
    debug(`GET (${this.filename}):`);
    if (this.lookahead != null) {
      debug(`   RETURN (${this.filename}) lookahead token`);
      save = this.lookahead;
      this.lookahead = undef;
      return save;
    }
    if (line = this.getFromAlt()) {
      debug(`   RETURN (${this.filename}) '${line}' from alt input`);
      return line;
    }
    line = this.fetch();
    if (line == null) {
      debug(`   RETURN (${this.filename}) undef - at EOF`);
      return undef;
    }
    result = this._mapped(line);
    while ((result == null) && (this.lBuffer.length > 0)) {
      line = this.fetch();
      result = this._mapped(line);
    }
    debug(`   RETURN (${this.filename}) '${result}'`);
    return result;
  }

  // ........................................................................
  _mapped(line) {
    var altLine, base, dir, lResult, level, result, str;
    assert(isString(line), `Not a string: '${line}'`);
    debug(`   _MAPPED: '${line}'`);
    assert(this.lookahead == null, "_mapped(): lookahead exists");
    if (line == null) {
      return undef;
    }
    [level, str] = splitLine(line);
    if (lResult = this.checkForInclude(str)) {
      assert(!this.altInput, "get(): altInput already set");
      [dir, base] = lResult;
      this.altInput = new FileInput(`${dir}/${base}`, {
        prefix: indentation(level),
        hIncludePaths: this.hIncludePaths
      });
      debug("   alt input created");
      altLine = this.getFromAlt();
      if (altLine != null) {
        debug(`   _mapped(): line becomes '${altLine}'`);
        line = altLine;
      } else {
        debug(`   _mapped(): alt was undef, retain line '${line}'`);
      }
    }
    result = this.mapLine(line);
    debug(`      mapped to '${result}'`);
    if (result != null) {
      if (isString(result)) {
        result = this.prefix + result;
      }
      debug(`      _mapped(): returning '${result}'`);
      return result;
    } else {
      debug("      _mapped(): returning undef");
      return undef;
    }
  }

  // ........................................................................
  // --- This should be used to fetch from @lBuffer
  //     to maintain proper @lineNum for error messages
  fetch() {
    if (this.lBuffer.length === 0) {
      return undef;
    }
    this.lineNum += 1;
    return this.lBuffer.shift();
  }

  // ........................................................................
  // --- Put one or more lines into lBuffer, to be fetched later
  //     TO DO: maintain correct line numbering!!!
  unfetch(block) {
    var lLines;
    lLines = stringToArray(block);
    return this.lBuffer.unshift(...lLines);
  }

  // ........................................................................
  // --- Fetch a block of text at level or greater than 'level'
  //     as one long string
  // --- Designed to use in mapLine()
  fetchBlock(atLevel) {
    var base, dir, i, lLines, lResult, len, level, line, oInput, ref, str;
    lLines = [];
    // --- NOTE: I absolutely hate using a backslash for line continuation
    //           but CoffeeScript doesn't continue while there is an
    //           open parenthesis like Python does :-(
    while ((this.lBuffer.length > 0) && ([level, str] = splitLine(this.lBuffer[0])) && (level >= atLevel) && (line = this.fetch())) {
      if (lResult = this.checkForInclude(str)) {
        [dir, base] = lResult;
        oInput = new FileInput(`${dir}/${base}`, {
          prefix: indentation(level),
          hIncludePaths: this.hIncludePaths
        });
        ref = oInput.getAll();
        for (i = 0, len = ref.length; i < len; i++) {
          line = ref[i];
          lLines.push(line);
        }
      } else {
        lLines.push(indentedStr(str, level - atLevel));
      }
    }
    return lLines.join('\n');
  }

  // ........................................................................
  getAll() {
    var lLines, line;
    lLines = [];
    line = this.get();
    while (line != null) {
      lLines.push(line);
      line = this.get();
    }
    return lLines;
  }

  // ........................................................................
  getAllText() {
    return this.getAll().join('\n');
  }

};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
//   class FileInput - contents from a file
export var FileInput = class FileInput extends StringInput {
  constructor(filename, hOptions = {}) {
    var base, content, dir, ext, root;
    ({root, dir, base, ext} = pathlib.parse(filename.trim()));
    hOptions.filename = base;
    if (unitTesting) {
      content = `Contents of ${base}`;
    } else {
      if (!fs.existsSync(filename)) {
        error(`FileInput(): file '${filename}' does not exist`);
      }
      content = slurp(filename);
    }
    super(content, hOptions);
  }

};

// ---------------------------------------------------------------------------
