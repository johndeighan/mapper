// Generated by CoffeeScript 2.6.1
// Symbols.coffee
var SymbolParser, getAvailSymbolsFrom;

import CoffeeScript from 'coffeescript';

import {
  assert,
  undef,
  isString,
  isArray,
  croak,
  uniq,
  words
} from '@jdeighan/coffee-utils';

import {
  barf,
  slurp,
  pathTo,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  Mapper,
  SmartMapper
} from '@jdeighan/mapper';

import {
  ASTWalker
} from '@jdeighan/mapper/walker';

export var symbolsRootDir = mkpath(process.cwd());

// ---------------------------------------------------------------------------
export var setSymbolsRootDir = function(dir) {
  symbolsRootDir = dir;
};

// ---------------------------------------------------------------------------
export var getNeededSymbols = function(coffeeCode, hOptions = {}) {
  var ast, err, hSymbolInfo, walker;
  // --- Valid options:
  //        dumpfile: <filepath>   - where to dump ast
  //     NOTE: array returned will always be unique
  debug("enter getNeededSymbols()");
  assert(isString(coffeeCode), "getNeededSymbols(): code not a string");
  try {
    debug("COMPILE CODE", coffeeCode);
    ast = CoffeeScript.compile(coffeeCode, {
      ast: true
    });
    assert(ast != null, "getNeededSymbols(): ast is empty");
  } catch (error) {
    err = error;
    croak(err, 'CODE (in getNeededSymbols)', coffeeCode);
  }
  walker = new ASTWalker(ast);
  hSymbolInfo = walker.getSymbols();
  if (hOptions.dumpfile) {
    barf(hOptions.dumpfile, "AST:\n" + tamlStringify(ast));
  }
  debug("return from getNeededSymbols()");
  return uniq(hSymbolInfo.lNeeded);
};

// ---------------------------------------------------------------------------
export var buildImportList = function(lNeededSymbols, hOptions = {}) {
  var hAvailSymbols, hLibs, hSymbol, isDefault, j, k, lImports, len, len1, lib, ref, src, str, strSymbols, symbol;
  // --- Valid options:
  //     recurse - search upward for .symbols files
  debug("enter buildImportList()");
  debug("lNeededSymbols", lNeededSymbols);
  if (!lNeededSymbols || (lNeededSymbols.length === 0)) {
    debug("return from buildImportList() - no needed symbols");
    return [];
  }
  hLibs = {}; // { <lib>: [<symbol>, ... ], ... }
  lImports = [];
  // --- { <sym>: {lib: <lib>, src: <name> }}
  hAvailSymbols = getAvailSymbols();
  for (j = 0, len = lNeededSymbols.length; j < len; j++) {
    symbol = lNeededSymbols[j];
    hSymbol = hAvailSymbols[symbol];
    if (hSymbol != null) {
      // --- symbol is available in lib
      ({lib, src, isDefault} = hSymbol);
      if (isDefault) {
        lImports.push(`import ${symbol} from '${lib}'`);
      } else {
        // --- build the needed string
        if (src != null) {
          str = `${src} as ${symbol}`;
        } else {
          str = symbol;
        }
        if (hLibs[lib] != null) {
          assert(isArray(hLibs[lib]), "buildImportList(): not an array");
          hLibs[lib].push(str);
        } else {
          hLibs[lib] = [str];
        }
      }
    }
  }
  ref = Object.keys(hLibs).sort();
  for (k = 0, len1 = ref.length; k < len1; k++) {
    lib = ref[k];
    strSymbols = hLibs[lib].join(',');
    lImports.push(`import {${strSymbols}} from '${lib}'`);
  }
  debug("return from buildImportList()", lImports);
  return lImports;
};

// ---------------------------------------------------------------------------
// export only to allow unit testing
export var getAvailSymbols = function() {
  var filepath, hSymbols;
  // --- returns { <symbol> -> {lib: <lib>, src: <name>, default: true},...}
  debug("enter getAvailSymbols()");
  assert(symbolsRootDir, "empty symbolsRootDir");
  debug(`search for .symbols from '${symbolsRootDir}'`);
  filepath = pathTo('.symbols', symbolsRootDir, 'up');
  if (filepath == null) {
    debug("return from getAvailSymbols() - no .symbols file found");
    return {};
  }
  hSymbols = getAvailSymbolsFrom(filepath);
  debug("hSymbols", hSymbols);
  debug("return from getAvailSymbols()");
  return hSymbols;
};

// ---------------------------------------------------------------------------
getAvailSymbolsFrom = function(filepath) {
  var contents, hSymbols, parser;
  // --- returns { <symbol> -> {lib: <lib>, src: <name>}, ... }
  debug(`enter getAvailSymbolsFrom('${filepath}')`);
  contents = slurp(filepath);
  debug('Contents of .symbols', contents);
  parser = new SymbolParser(contents);
  hSymbols = parser.getSymbols();
  debug("hSymbols", hSymbols);
  debug("return from getAvailSymbolsFrom()");
  return hSymbols;
};

// ---------------------------------------------------------------------------
SymbolParser = class SymbolParser extends SmartMapper {
  // --- Parse a .symbols file
  constructor(content) {
    super(content);
    this.curLib = undef;
    this.hSymbols = {};
  }

  mapString(line, level) {
    var _, hDesc, i, isDefault, j, lMatches, lWords, len, nextWord, numWords, src, symbol, word;
    if (level === 0) {
      this.curLib = line;
    } else if (level === 1) {
      assert(this.curLib != null, "mapString(): curLib not defined");
      lWords = words(line);
      numWords = lWords.length;
      for (i = j = 0, len = lWords.length; j < len; i = ++j) {
        word = lWords[i];
        symbol = src = undef;
        // --- set variables symbol and possibly src
        if (lMatches = word.match(/^(\*?)([A-Za-z_][A-Za-z0-9_]*)$/)) {
          [_, isDefault, symbol] = lMatches;
          // --- word is an identifier (skip words that contain '(' or ')')
          if (i + 2 < numWords) {
            nextWord = lWords[i + 1];
            if (nextWord === '(as') {
              lMatches = lWords[i + 2].match(/^([A-Za-z_][A-Za-z0-9_]*)\)$/);
              if (lMatches) {
                src = symbol;
                symbol = lMatches[1];
              }
            }
          }
        }
        if (symbol != null) {
          assert(this.hSymbols[symbol] == null, `SymbolParser: duplicate symbol ${symbol}`);
          hDesc = {
            lib: this.curLib
          };
          if (src != null) {
            hDesc.src = src;
          }
          if (isDefault) {
            hDesc.isDefault = true;
          }
          this.hSymbols[symbol] = hDesc;
        }
      }
    } else {
      croak(`Bad .symbols file - level = ${level}`);
    }
    return undef; // doesn't matter what we return
  }

  getSymbols() {
    this.getAll();
    return this.hSymbols;
  }

};

// ---------------------------------------------------------------------------
