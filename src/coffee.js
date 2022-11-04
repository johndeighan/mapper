// Generated by CoffeeScript 2.7.0
// coffee.coffee
var expand, projRoot;

import CoffeeScript from 'coffeescript';

import {
  LOG,
  LOGVALUE,
  assert,
  croak
} from '@jdeighan/base-utils';

import {
  dbg,
  dbgEnter,
  dbgReturn
} from '@jdeighan/base-utils/debug';

import {
  CWS,
  undef,
  defined,
  OL,
  sep_dash
} from '@jdeighan/coffee-utils';

import {
  indentLevel,
  isUndented,
  indented
} from '@jdeighan/coffee-utils/indent';

import {
  mkpath,
  barf
} from '@jdeighan/coffee-utils/fs';

import {
  Mapper,
  map
} from '@jdeighan/mapper';

import {
  TreeMapper
} from '@jdeighan/mapper/tree';

projRoot = mkpath('c:', 'Users', 'johnd', 'mapper');

// ---------------------------------------------------------------------------
export var brew = function(code, source = 'internal') {
  var hCoffeeOptions, mapped, result;
  hCoffeeOptions = {
    bare: true,
    header: false
  };
  mapped = map(source, code, CoffeePreProcessor);
  result = CoffeeScript.compile(mapped, hCoffeeOptions);
  // --- Result is JS code
  return result.trim();
};

// ---------------------------------------------------------------------------
export var coffeeExprToJS = function(coffeeExpr) {
  var err, jsExpr, pos;
  assert(isUndented(coffeeExpr), "has indentation");
  dbgEnter("coffeeExprToJS");
  try {
    jsExpr = brew(coffeeExpr);
    // --- Remove any trailing semicolon
    pos = jsExpr.length - 1;
    if (jsExpr.substr(pos, 1) === ';') {
      jsExpr = jsExpr.substr(0, pos);
    }
  } catch (error) {
    err = error;
    croak(err, "coffeeExprToJS", coffeeExpr);
  }
  dbgReturn("coffeeExprToJS", jsExpr);
  return jsExpr;
};

// ---------------------------------------------------------------------------
// --- Available options in hOptions:
//        bare: boolean   - compile without top-level function wrapper
//        header: boolean - include "Generated by CoffeeScript" comment
//        ast: boolean - include AST in return value
//        transpile - options object to use with Babel
//        sourceMap - generate a source map
//        filename - name of the source map file
//        inlineMap - generate source map inside the JS file
// ---------------------------------------------------------------------------
export var coffeeCodeToJS = function(coffeeCode, source = undef, hOptions = {}) {
  var err, jsCode;
  assert(isUndented(coffeeCode), "has indentation");
  dbgEnter("coffeeCodeToJS", coffeeCode, source, hOptions);
  try {
    jsCode = brew(coffeeCode, source);
    // --- cleanJS() does:
    //        1. remove blank lines
    //        2. remove trailing newline
    jsCode = cleanJS(jsCode);
  } catch (error) {
    err = error;
    croak(err, "Original Code", coffeeCode);
  }
  dbgReturn("coffeeCodeToJS", jsCode);
  return jsCode;
};

// ---------------------------------------------------------------------------
export var coffeeFileToJS = function(srcPath, destPath = undef, hOptions = {}) {
  var coffeeCode, dumpfile, i, jsCode, lNeeded, len, n, sym, word;
  if (destPath == null) {
    destPath = withExt(srcPath, '.js', {
      removeLeadingUnderScore: true
    });
  }
  if (hOptions.force || !newerDestFileExists(srcPath, destPath)) {
    coffeeCode = slurp(srcPath);
    if (hOptions.saveAST) {
      dumpfile = withExt(srcPath, '.ast');
      lNeeded = getNeededSymbols(coffeeCode, {dumpfile});
      if ((lNeeded === undef) || (lNeeded.length === 0)) {
        dbg(`NO NEEDED SYMBOLS in ${shortenPath(destPath)}:`);
      } else {
        n = lNeeded.length;
        word = n === 1 ? 'SYMBOL' : 'SYMBOLS';
        dbg(`${n} NEEDED ${word} in ${shortenPath(destPath)}:`);
        for (i = 0, len = lNeeded.length; i < len; i++) {
          sym = lNeeded[i];
          dbg(`   - ${sym}`);
        }
      }
    }
    jsCode = coffeeCodeToJS(coffeeCode, srcPath, hOptions);
    barf(destPath, jsCode);
  }
};

// ---------------------------------------------------------------------------
export var coffeeCodeToAST = function(coffeeCode, source = undef) {
  var ast, err, mapped;
  assert(isUndented(coffeeCode), "has indentation");
  dbgEnter("coffeeCodeToAST", coffeeCode, source);
  barf(mkpath(projRoot, 'test', 'ast.coffee'), coffeeCode);
  try {
    mapped = map(source, coffeeCode, CoffeePreProcessor);
    assert(defined(mapped), "mapped is undef");
    barf(mkpath(projRoot, 'test', 'ast.cielo'), mapped);
  } catch (error) {
    err = error;
    barf(mkpath(projRoot, 'test', 'ast.coffee'), coffeeCode);
    croak(`ERROR in CoffeePreProcessor: ${err.message}`);
  }
  try {
    ast = CoffeeScript.compile(mapped, {
      ast: true
    });
    assert(defined(ast), "ast is empty");
  } catch (error) {
    err = error;
    LOG(`ERROR in CoffeeScript: ${err.message}`);
    LOG(sep_dash);
    LOG(`${OL(coffeeCode)}`);
    LOG(sep_dash);
    croak(`ERROR in CoffeeScript: ${err.message}`);
  }
  dbgReturn("coffeeCodeToAST", ast);
  return ast;
};

// ---------------------------------------------------------------------------
export var cleanJS = function(jsCode) {
  jsCode = jsCode.replace(/\n\n+/gs, "\n"); // multiple NL to single NL
  jsCode = jsCode.replace(/\n$/s, ''); // strip trailing whitespace
  return jsCode;
};

// ---------------------------------------------------------------------------
export var minifyJS = function(jsCode, lParms) {
  jsCode = CWS(jsCode);
  jsCode = jsCode.replace(/,\s+/, ',');
  return jsCode;
};

// ---------------------------------------------------------------------------
expand = function(qstr) {
  var lMatches, result;
  lMatches = qstr.match(/^\"(.*)\"$/);
  assert(defined(lMatches), `Bad arg: ${OL(qstr)}`);
  assert(lMatches[1].indexOf('"') === -1, `Bad arg: ${OL(qstr)}`);
  return result = qstr.replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, function(_, ident) {
    return `\#{OL(${ident})}`;
  });
};

// ---------------------------------------------------------------------------
export var CoffeePreProcessor = class CoffeePreProcessor extends TreeMapper {
  mapComment(hNode) {
    var level, result, str;
    // --- Retain comments
    dbgEnter("mapComment");
    ({str, level} = hNode);
    result = indented(str, level, this.oneIndent);
    dbgReturn("mapComment", result);
    return result;
  }

  // ..........................................................
  mapNode(hNode) {
    var level, result, str;
    // --- only non-special nodes
    dbgEnter("mapNode", hNode);
    ({str, level} = hNode);
    result = str.replace(/\"[^"]*\"/g, function(qstr) { // sequence of non-quote characters
      return expand(qstr);
    });
    result = indented(result, level, this.oneIndent);
    dbgReturn("mapNode", result);
    return result;
  }

};
