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
  setUnitTesting,
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
    var base, dir, ext, filename, hIncludePaths, mapper, prefix, ref;
    this.hOptions = hOptions1;
    // --- Valid options:
    //        filename
    //        mapper
    //        prefix        # auto-prepended to each defined ret val
    //                      # from _mapped()
    //        hIncludePaths    { <ext>: <dir>, ... }
    ({filename, mapper, prefix, hIncludePaths} = this.hOptions);
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
    this.mapper = mapper;
    this.prefix = prefix || '';
    this.hIncludePaths = this.hOptions.hIncludePaths || {};
    ref = this.hIncludePaths;
    for (ext in ref) {
      if (!hasProp.call(ref, ext)) continue;
      dir = ref[ext];
      assert(ext.indexOf('.') === 0, "invalid key in hIncludePaths");
      assert(fs.existsSync(dir), `dir ${dir} does not exist`);
    }
    this.lookahead = undef; // lookahead token, placed by unget
    this.altInput = undef;
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
  // --- Doesn't return anything - sets up @altInput
  checkForInclude(line) {
    var _, base, dir, ext, filename, fname, lMatches, level, root, str;
    assert(!this.altInput, "checkForInclude(): altInput already set");
    [level, str] = splitLine(line);
    if (lMatches = str.match(/^\#include\s*(.*)$/)) {
      [_, fname] = lMatches;
      filename = fname.trim();
      ({root, dir, base, ext} = pathlib.parse(filename));
      if (!root && !dir && this.hIncludePaths && (dir = this.hIncludePaths[ext])) {
        assert(base === filename, `base = ${base}, filename = ${filename}`);
        // --- It's a plain file name with an extension
        //     that we can handle
        this.altInput = new FileInput(`${dir}/${base}`, {
          filename: fname,
          mapper: this.mapper,
          prefix: indentation(level),
          hIncludePaths: this.hIncludePaths
        });
        debug("   alt input created");
      }
    }
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
    // --- Handle #include here, before calling @_mapped
    this.checkForInclude(line);
    if (this.altInput) {
      result = this.getFromAlt();
      debug(`   RETURN (${this.filename}) '${result}' from alt input after #include`);
      return result;
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
    var result;
    assert(isString(line), `Not a string: '${line}'`);
    debug(`   _MAPPED: '${line}'`);
    assert(this.lookahead == null, "_mapped(): lookahead exists");
    if (line == null) {
      return undef;
    }
    if (this.mapper) {
      result = this.mapper(line, this);
      debug(`      mapped to '${result}'`);
    } else {
      result = line;
    }
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
  // --- Designed to use in a mapper
  fetchBlock(atLevel) {
    var block, level, line, str;
    block = '';
    // --- NOTE: I absolutely hate using a backslash for line continuation
    //           but CoffeeScript doesn't continue while there is an
    //           open parenthesis like Python does :-(
    while ((this.lBuffer.length > 0) && ([level, str] = splitLine(this.lBuffer[0])) && (level >= atLevel) && (line = this.fetch())) {
      block += line + '\n';
    }
    return block;
  }

  // ........................................................................
  getFileContents(filename) {
    var base, dir, ext, name, root;
    ({dir, root, base, name, ext} = pathlib.parse(filename));
    if (dir) {
      error(`#include: Full paths not allowed: '${filename}'`);
    }
    dir = this.hIncludePaths[ext];
    if (dir == null) {
      error(`#include: invalid extension: '${filename}'`);
    }
    if (unitTesting) {
      return `Contents of ${filename}`;
    } else {
      return slurp(`${dir}/${base}`);
    }
  }

};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
//   class FileInput - contents from a file
export var FileInput = class FileInput extends StringInput {
  constructor(filename, hOptions = {}) {
    var content;
    if (!fs.existsSync(filename)) {
      error(`FileInput(): file '${filename}' does not exist`);
    }
    content = fs.readFileSync(filename).toString();
    hOptions.filename = filename;
    super(content, hOptions);
  }

};

// ---------------------------------------------------------------------------
//   utility func for processing content using a mapper
export var procContent = function(content, mapper) {
  var lLines, line, oInput, result;
  debug(sep_dash);
  debug(content, "CONTENT (before proc):");
  debug(sep_dash);
  oInput = new StringInput(content, {
    filename: 'proc',
    mapper
  });
  lLines = [];
  while (line = oInput.get()) {
    lLines.push(line);
  }
  if (lLines.length === 0) {
    result = '';
  } else {
    result = lLines.join('\n') + '\n';
  }
  debug(sep_dash);
  debug(result, "CONTENT (after proc):");
  debug(sep_dash);
  return result;
};
