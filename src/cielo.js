// Generated by CoffeeScript 2.7.0
  // cielo.coffee
import {
  assert,
  error,
  croak
} from '@jdeighan/unit-tester/utils';

import {
  undef,
  defined,
  OL,
  replaceVars,
  className,
  isEmpty,
  nonEmpty,
  isString,
  isHash,
  isArray
} from '@jdeighan/coffee-utils';

import {
  LOG,
  DEBUG
} from '@jdeighan/coffee-utils/log';

import {
  indentLevel,
  isUndented,
  splitLine
} from '@jdeighan/coffee-utils/indent';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  joinBlocks
} from '@jdeighan/coffee-utils/block';

import {
  withExt,
  slurp,
  barf,
  newerDestFileExists,
  shortenPath
} from '@jdeighan/coffee-utils/fs';

import {
  TreeWalker
} from '@jdeighan/mapper/tree';

import {
  coffeeCodeToJS
} from '@jdeighan/mapper/coffee';

import {
  getNeededSymbols,
  buildImportList
} from '@jdeighan/mapper/symbols';

import {
  doMap,
  Mapper
} from '@jdeighan/mapper';

// ---------------------------------------------------------------------------
export var cieloCodeToJS = function(cieloCode, source = undef, hOptions = {}) {
  var coffeeCode, err, hCoffeeOptions, jsCode, jsPreCode, lImports, lNeededSymbols, postmapper, premapper, stmt;
  // --- cielo => js
  //     Valid Options:
  //        premapper:  Mapper or subclass
  //        postmapper: Mapper or subclass - optional
  //        hCoffeeOptions  - passed to CoffeeScript.parse()
  //           default:
  //              bare: true
  //              header: false
  //     If hOptions is a string, it's assumed to be the source
  debug("enter cieloCodeToJS()", cieloCode, source, hOptions);
  assert(isUndented(cieloCode), "cieloCode has indent");
  assert(isHash(hOptions), "hOptions not a hash");
  if (hOptions.premapper) {
    premapper = hOptions.premapper;
    assert((premapper.prototype instanceof Mapper) || (premapper === Mapper), "premapper not a Mapper");
  } else {
    premapper = TreeWalker;
  }
  postmapper = hOptions.postmapper; // may be undef
  if (defined(postmapper)) {
    assert((postmapper.prototype instanceof Mapper) || (postmapper === Mapper), "postmapper not a Mapper");
  }
  // --- Handles extension lines, HEREDOCs, etc.
  debug(`Apply premapper ${className(premapper)}`);
  coffeeCode = doMap(premapper, source, cieloCode);
  if (coffeeCode !== cieloCode) {
    assert(isUndented(coffeeCode), "coffeeCode has indent");
    debug("coffeeCode", coffeeCode);
  }
  // --- symbols will always be unique
  //     We can only get needed symbols from coffee code, not JS code
  lNeededSymbols = getNeededSymbols(coffeeCode);
  debug(`${lNeededSymbols.length} needed symbols`, lNeededSymbols);
  try {
    hCoffeeOptions = hOptions.hCoffeeOptions;
    jsPreCode = coffeeCodeToJS(coffeeCode, source, hCoffeeOptions);
    debug("jsPreCode", jsPreCode);
    if (postmapper) {
      jsCode = doMap(postmapper, source, jsPreCode);
      if (jsCode !== jsPreCode) {
        debug("post mapped", jsCode);
      }
    } else {
      jsCode = jsPreCode;
    }
  } catch (error1) {
    err = error1;
    croak(err, "Original Code", cieloCode);
  }
  // --- Prepend needed imports
  lImports = buildImportList(lNeededSymbols, source);
  debug("lImports", lImports);
  assert(isArray(lImports), "cieloCodeToJS(): lImports is not an array");
  // --- append ';' to import statements
  lImports = (function() {
    var i, len, results;
    results = [];
    for (i = 0, len = lImports.length; i < len; i++) {
      stmt = lImports[i];
      results.push(stmt + ';');
    }
    return results;
  })();
  // --- joinBlocks() flattens all its arguments to array of strings
  jsCode = joinBlocks(lImports, jsCode);
  debug("return from cieloCodeToJS()", jsCode);
  return jsCode;
};

// ---------------------------------------------------------------------------
export var cieloCodeToCoffee = function(cieloCode, source = undef, hOptions = {}) {
  var coffeeCode, lImports, lNeededSymbols, newCoffeeCode, postmapper, premapper;
  // --- cielo => coffee
  //     Valid Options:
  //        premapper:  Mapper or subclass
  //        postmapper: Mapper or subclass - optional
  //        hCoffeeOptions  - passed to CoffeeScript.parse()
  //           default:
  //              bare: true
  //              header: false
  //     If hOptions is a string, it's assumed to be the source
  debug("enter cieloCodeToCoffee()", cieloCode, source, hOptions);
  assert(isUndented(cieloCode), "cieloCode has indent");
  assert(isHash(hOptions), "hOptions not a hash");
  if (hOptions.premapper) {
    premapper = hOptions.premapper;
    assert((premapper.prototype instanceof Mapper) || (premapper === Mapper), "premapper not a Mapper");
  } else {
    premapper = TreeWalker;
  }
  postmapper = hOptions.postmapper; // may be undef
  if (defined(postmapper)) {
    assert((postmapper.prototype instanceof Mapper) || (postmapper === Mapper), "postmapper not a Mapper");
  }
  // --- Handles extension lines, HEREDOCs, etc.
  debug(`Apply premapper ${className(premapper)}`);
  coffeeCode = doMap(premapper, source, cieloCode);
  if (coffeeCode !== cieloCode) {
    assert(isUndented(coffeeCode), "coffeeCode has indent");
    debug("coffeeCode", coffeeCode);
  }
  // --- symbols will always be unique
  //     We can only get needed symbols from coffee code, not JS code
  lNeededSymbols = getNeededSymbols(coffeeCode);
  debug(`${lNeededSymbols.length} needed symbols`, lNeededSymbols);
  if (postmapper) {
    newCoffeeCode = doMap(postmapper, source, coffeeCode);
    if (newCoffeeCode !== coffeeCode) {
      coffeeCode = newCoffeeCode;
      debug("post mapped", coffeeCode);
    }
  }
  // --- Prepend needed imports
  lImports = buildImportList(lNeededSymbols, source);
  debug("lImports", lImports);
  assert(isArray(lImports), "cieloCodeToCoffee(): lImports is not an array");
  // --- joinBlocks() flattens all its arguments to array of strings
  coffeeCode = joinBlocks(lImports, coffeeCode);
  debug("return from cieloCodeToCoffee()", coffeeCode);
  return coffeeCode;
};

// ---------------------------------------------------------------------------
export var cieloFileToJS = function(srcPath, destPath = undef, hOptions = {}) {
  var cieloCode, dumpfile, i, jsCode, lNeeded, len, n, sym, word;
  if (destPath == null) {
    destPath = withExt(srcPath, '.js', {
      removeLeadingUnderScore: true
    });
  }
  if (hOptions.force || !newerDestFileExists(srcPath, destPath)) {
    cieloCode = slurp(srcPath);
    if (hOptions.saveAST) {
      dumpfile = withExt(srcPath, '.ast');
      lNeeded = getNeededSymbols(cieloCode, {dumpfile});
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
    jsCode = cieloCodeToJS(cieloCode, srcPath, hOptions);
    barf(destPath, jsCode);
  }
};
