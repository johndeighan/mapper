// Generated by CoffeeScript 2.7.0
// coffee.coffee
var expand;

import CoffeeScript from 'coffeescript';

import {
  assert,
  error,
  croak
} from '@jdeighan/unit-tester/utils';

import {
  CWS,
  undef,
  defined,
  OL
} from '@jdeighan/coffee-utils';

import {
  log,
  LOG,
  DEBUG
} from '@jdeighan/coffee-utils/log';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  indentLevel,
  isUndented
} from '@jdeighan/coffee-utils/indent';

import {
  Mapper,
  doMap
} from '@jdeighan/mapper';

// ---------------------------------------------------------------------------
export var brew = function(code, source = 'internal') {
  var hCoffeeOptions, mapped, result;
  hCoffeeOptions = {
    bare: true,
    header: false
  };
  mapped = doMap(CoffeePreProcessor, source, code);
  result = CoffeeScript.compile(mapped, hCoffeeOptions);
  // --- Result is JS code
  return result.trim();
};

// ---------------------------------------------------------------------------
export var getAST = function(code, source = 'internal') {
  var hCoffeeOptions, mapped, result;
  hCoffeeOptions = {
    ast: true
  };
  mapped = doMap(CoffeePreProcessor, source, code);
  result = CoffeeScript.compile(mapped, hCoffeeOptions);
  // --- Result is an AST
  return result;
};

// ---------------------------------------------------------------------------
export var coffeeExprToJS = function(coffeeExpr) {
  var err, jsExpr, pos;
  assert(isUndented(coffeeExpr), "has indentation");
  debug("enter coffeeExprToJS()");
  try {
    jsExpr = brew(coffeeExpr);
    // --- Remove any trailing semicolon
    pos = jsExpr.length - 1;
    if (jsExpr.substr(pos, 1) === ';') {
      jsExpr = jsExpr.substr(0, pos);
    }
  } catch (error1) {
    err = error1;
    croak(err, "coffeeExprToJS", coffeeExpr);
  }
  debug("return from coffeeExprToJS()", jsExpr);
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
  debug("enter coffeeCodeToJS()", coffeeCode);
  try {
    jsCode = brew(coffeeCode, source);
    // --- cleanJS() does:
    //        1. remove blank lines
    //        2. remove trailing newline
    jsCode = cleanJS(jsCode);
  } catch (error1) {
    err = error1;
    croak(err, "Original Code", coffeeCode);
  }
  debug("return from coffeeCodeToJS()", jsCode);
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
        debug(`NO NEEDED SYMBOLS in ${shortenPath(destPath)}:`);
      } else {
        n = lNeeded.length;
        word = n === 1 ? 'SYMBOL' : 'SYMBOLS';
        debug(`${n} NEEDED ${word} in ${shortenPath(destPath)}:`);
        for (i = 0, len = lNeeded.length; i < len; i++) {
          sym = lNeeded[i];
          debug(`   - ${sym}`);
        }
      }
    }
    jsCode = coffeeCodeToJS(coffeeCode, srcPath, hOptions);
    barf(destPath, jsCode);
  }
};

// ---------------------------------------------------------------------------
export var coffeeCodeToAST = function(coffeeCode, source = undef) {
  var ast, err;
  assert(isUndented(coffeeCode), "has indentation");
  debug("enter coffeeCodeToAST()", coffeeCode);
  try {
    ast = getAST(coffeeCode, source);
    assert(ast != null, "ast is empty");
  } catch (error1) {
    err = error1;
    croak(err, "in coffeeCodeToAST", coffeeCode);
  }
  debug("return from coffeeCodeToAST()", ast);
  return ast;
};

// ---------------------------------------------------------------------------
export var cleanJS = function(jsCode) {
  jsCode = jsCode.replace(/\n\n+/gs, "\n");
  jsCode = jsCode.replace(/\n$/s, '');
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
export var CoffeePreProcessor = class CoffeePreProcessor extends Mapper {
  mapComment(hLine) {
    // --- Retain comments
    return hLine.line;
  }

  // ..........................................................
  mapNonSpecial(hLine) {
    var result;
    debug("enter CoffeePreProcessor.mapNonSpecial()", hLine);
    result = hLine.str.replace(/\"[^"]*\"/g, function(qstr) { // sequence of non-quote characters
      return expand(qstr);
    });
    debug("return from CoffeePreProcessor.mapNonSpecial()", result);
    return result;
  }

};
