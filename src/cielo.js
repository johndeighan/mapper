// Generated by CoffeeScript 2.7.0
  // cielo.coffee
import {
  undef,
  assert,
  croak,
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
  coffeeCodeToJS
} from '@jdeighan/mapper/coffee';

import {
  FuncHereDoc
} from '@jdeighan/mapper/func';

import {
  getNeededSymbols,
  buildImportList
} from '@jdeighan/mapper/symbols';

import {
  TAMLHereDoc
} from '@jdeighan/mapper/taml';

import {
  doMap,
  Mapper
} from '@jdeighan/mapper';

import {
  TreeWalker
} from '@jdeighan/mapper/tree';

import {
  addHereDocType,
  lineToParts,
  mapHereDoc
} from '@jdeighan/mapper/heredoc';

addHereDocType(new FuncHereDoc());

addHereDocType(new TAMLHereDoc());

export var convertingCielo = true;

// ---------------------------------------------------------------------------
export var convertCielo = function(flag) {
  convertingCielo = flag;
};

// ---------------------------------------------------------------------------
export var cieloCodeToJS = function(cieloCode, hOptions) {
  var coffeeCode, err, jsCode, jsPreCode, lImports, lNeededSymbols, postmapper, premapper, source, stmt;
  // --- cielo => js
  //     Valid Options:
  //        premapper:  Mapper or subclass
  //        postmapper: Mapper or subclass - optional
  //        source: name of source file
  //        hCoffeeOptions  - passed to CoffeeScript.parse()
  //           default:
  //              bare: true
  //              header: false
  //     If hOptions is a string, it's assumed to be the source
  debug("enter cieloCodeToJS()");
  debug("cieloCode", cieloCode);
  debug('hOptions', hOptions);
  assert(isUndented(cieloCode), "cieloCodeToJS(): has indent");
  if (isString(hOptions)) {
    source = hOptions;
    premapper = TreeWalker;
    postmapper = undef;
  } else if (isHash(hOptions)) {
    premapper = hOptions.premapper || TreeWalker;
    postmapper = hOptions.postmapper; // may be undef
    source = hOptions.source;
  } else {
    croak(`Invalid 2nd parm: ${OL(hOptions)}`);
  }
  assert(source != null, "Missing source");
  // --- Handles extension lines, HEREDOCs, etc.
  debug(`Apply premapper ${className(premapper)}`);
  coffeeCode = doMap(premapper, source, cieloCode);
  if (coffeeCode !== cieloCode) {
    debug("coffeeCode", coffeeCode);
  }
  // --- symbols will always be unique
  //     We can only get needed symbols from coffee code, not JS code
  lNeededSymbols = getNeededSymbols(coffeeCode);
  debug(`${lNeededSymbols.length} needed symbols`, lNeededSymbols);
  try {
    if (convertingCielo) {
      jsPreCode = coffeeCodeToJS(coffeeCode, hOptions.hCoffeeOptions);
      debug("jsPreCode", jsPreCode);
    } else {
      jsPreCode = cieloCode;
    }
    if (postmapper) {
      jsCode = doMap(postmapper, source, jsPreCode);
      if (jsCode !== jsPreCode) {
        debug("post mapped", jsCode);
      }
    } else {
      jsCode = jsPreCode;
    }
  } catch (error) {
    err = error;
    croak(err, "Original Code", cieloCode);
  }
  // --- Prepend needed imports
  lImports = buildImportList(lNeededSymbols, source);
  debug("lImports", lImports);
  assert(isArray(lImports), "cieloCodeToJS(): lImports is not an array");
  if (convertingCielo) {
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
  }
  // --- joinBlocks() flattens all its arguments to array of strings
  jsCode = joinBlocks(lImports, jsCode);
  debug("return from cieloCodeToJS()", jsCode);
  return jsCode;
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
    jsCode = cieloCodeToJS(cieloCode, hOptions);
    barf(destPath, jsCode);
  }
};
