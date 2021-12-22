// Generated by CoffeeScript 2.6.1
// coffee.coffee
var SymbolParser, convert, getAvailSymbolsFrom;

import CoffeeScript from 'coffeescript';

import {
  assert,
  croak,
  OL,
  escapeStr,
  isArray,
  isString,
  isEmpty,
  nonEmpty,
  words,
  undef,
  deepCopy,
  uniq,
  say
} from '@jdeighan/coffee-utils';

import {
  log,
  tamlStringify
} from '@jdeighan/coffee-utils/log';

import {
  joinBlocks
} from '@jdeighan/coffee-utils/block';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  mydir,
  pathTo,
  slurp,
  barf
} from '@jdeighan/coffee-utils/fs';

import {
  indentLevel,
  indented
} from '@jdeighan/coffee-utils/indent';

import {
  StringInput,
  SmartInput
} from '@jdeighan/string-input';

import {
  ASTWalker
} from '@jdeighan/string-input/tree';

convert = true;

// ---------------------------------------------------------------------------
export var convertCoffee = function(flag) {
  convert = flag;
};

// ---------------------------------------------------------------------------
export var brewExpr = function(expr, force = false) {
  var err, newexpr, pos;
  assert(indentLevel(expr) === 0, "brewExpr(): has indentation");
  if (!convert && !force) {
    return expr;
  }
  try {
    newexpr = CoffeeScript.compile(expr, {
      bare: true
    }).trim();
    // --- Remove any trailing semicolon
    pos = newexpr.length - 1;
    if (newexpr.substr(pos, 1) === ';') {
      newexpr = newexpr.substr(0, pos);
    }
  } catch (error) {
    err = error;
    croak(err, "brewExpr", expr);
  }
  return newexpr;
};

// ---------------------------------------------------------------------------
export var preBrewCoffee = function(...lBlocks) {
  var blk, err, i, j, lNeededSymbols, lNewBlocks, len, newblk, script;
  debug("enter preBrewCoffee()");
  lNeededSymbols = [];
  lNewBlocks = [];
  for (i = j = 0, len = lBlocks.length; j < len; i = ++j) {
    blk = lBlocks[i];
    debug(`BLOCK ${i}`, blk);
    newblk = preProcessCoffee(blk);
    debug("NEW BLOCK", newblk);
    // --- will always be unique
    lNeededSymbols = getNeededSymbols(newblk);
    if (convert) {
      try {
        script = CoffeeScript.compile(newblk, {
          bare: true
        });
        debug("BREWED SCRIPT", script);
        lNewBlocks.push(postProcessCoffee(script));
      } catch (error) {
        err = error;
        log("Mapped Text:", newblk);
        croak(err, "Original Text", blk);
      }
    } else {
      lNewBlocks.push(newblk);
    }
  }
  // --- return converted blocks, PLUS the list of import statements
  return [...lNewBlocks, buildImportList(lNeededSymbols)];
};

// ---------------------------------------------------------------------------
export var brewCoffee = function(code) {
  var lCodeBlocks, lImportStmts, newcode;
  lCodeBlocks = preBrewCoffee(code);
  lImportStmts = lCodeBlocks.pop();
  newcode = joinBlocks(...lImportStmts, lCodeBlocks);
  debug('CODE', code);
  debug('lImportStmts', lImportStmts);
  debug('lCodeBlocks', lCodeBlocks);
  debug('NEW CODE', newcode);
  return newcode;
};

// ---------------------------------------------------------------------------
/*

- converts
		<varname> <== <expr>

	to:
		`$:`
		<varname> = <expr>

	then to to:
		var <varname>;
		$:;
		<varname> = <js expr>;

	then to:
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

	then to:
		$:{;
		<js code>
		};

	then to:
		$:{
		<js code>
		}

*/
// ===========================================================================
export var StarbucksPreMapper = class StarbucksPreMapper extends SmartInput {
  mapString(line, level) {
    var _, code, expr, lMatches, result, varname;
    debug(`enter mapString(${OL(line)})`);
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
      assert(isEmpty(code), `mapString(): indented code not allowed after '${line}'`);
      assert(!isEmpty(expr), `mapString(): empty expression in '${line}'`);
      result = `\`$:\`
${varname} = ${expr}`;
    } else {
      debug("return from mapString() - no match");
      return line;
    }
    debug("return from mapString()", result);
    return result;
  }

};

// ---------------------------------------------------------------------------
export var preProcessCoffee = function(code) {
  var newcode, oInput;
  // --- Removes blank lines and comments
  //     inteprets <== as svelte reactive statement or block
  assert(indentLevel(code) === 0, "preProcessCoffee(): has indentation");
  oInput = new StarbucksPreMapper(code);
  newcode = oInput.getAllText();
  debug('newcode', newcode);
  return newcode;
};

// ---------------------------------------------------------------------------
export var StarbucksPostMapper = class StarbucksPostMapper extends StringInput {
  // --- variable declaration immediately following one of:
  //        $:{;
  //        $:;
  //     should be moved above this line
  mapLine(line, level) {
    var _, brace, lMatches, rest, result;
    // --- new properties, initially undef:
    //        @savedLevel
    //        @savedLine
    if (this.savedLine) {
      if (line.match(/^\s*var\s/)) {
        result = `${line}\n${this.savedLine}`;
      } else {
        result = `${this.savedLine}\n${line}`;
      }
      this.savedLine = undef;
      return result;
    }
    if ((lMatches = line.match(/^\$\:(\{)?\;(.*)$/))) { // optional {
      // any remaining text
      [_, brace, rest] = lMatches;
      assert(!rest, "StarbucksPostMapper: extra text after $:");
      this.savedLevel = level;
      if (brace) {
        this.savedLine = "$:{";
      } else {
        this.savedLine = "$:";
      }
      return undef;
    } else if ((lMatches = line.match(/^\}\;(.*)$/))) {
      [_, rest] = lMatches;
      assert(!rest, "StarbucksPostMapper: extra text after $:");
      return indented("\}", level);
    } else {
      return indented(line, level);
    }
  }

};

// ---------------------------------------------------------------------------
export var postProcessCoffee = function(code) {
  var oInput;
  // --- variable declaration immediately following one of:
  //        $:{
  //        $:
  //     should be moved above this line
  oInput = new StarbucksPostMapper(code);
  return oInput.getAllText();
};

// ---------------------------------------------------------------------------
export var buildImportList = function(lNeededSymbols) {
  var hAvailSymbols, hLibs, hSymbol, isDefault, j, k, lImports, len, len1, lib, ref, src, str, strSymbols, symbol;
  hLibs = {}; // { <lib>: [<symbol>, ... ], ... }
  lImports = [];
  hAvailSymbols = getAvailSymbols(); // { <sym>: {lib: <lib>, src: <name> }}
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
  return lImports;
};

// ---------------------------------------------------------------------------
export var getNeededSymbols = function(code, hOptions = {}) {
  var ast, err, hSymbolInfo, walker;
  // --- Valid options:
  //        dumpfile: <filepath>   - where to dump ast
  //     NOTE: array returned will always be unique
  assert(isString(code), "getNeededSymbols(): code must be a string");
  debug("enter getNeededSymbols()");
  try {
    debug("COMPILE CODE", code);
    ast = CoffeeScript.compile(code, {
      ast: true
    });
    assert(ast != null, "getNeededSymbols(): ast is empty");
  } catch (error) {
    err = error;
    croak(err, 'CODE (in getNeededSymbols)', code);
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
// export to allow unit testing
export var getAvailSymbols = function() {
  var dir, filepath, hSymbols;
  // --- returns { <symbol> -> {lib: <lib>, src: <name>, default: true},...}
  debug("enter getAvailSymbols()");
  dir = process.env.DIR_ROOT;
  if (!dir) {
    debug("return from getAvailSymbols() - env var DIR_SYMBOLS not set");
    return {};
  }
  debug(`search for .symbols from '${dir}'`);
  filepath = pathTo('.symbols', dir, 'up');
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
SymbolParser = class SymbolParser extends SmartInput {
  // --- We want to allow blank lines and comments
  //     We want to allow continuation lines
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
