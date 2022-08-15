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
  indented,
  isUndented,
  splitLine
} from '@jdeighan/coffee-utils/indent';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  joinBlocks,
  arrayToBlock,
  blockToArray
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
  map,
  Mapper
} from '@jdeighan/mapper';

// ---------------------------------------------------------------------------
export var CieloToCoffeeMapper = class CieloToCoffeeMapper extends TreeWalker {
  mapComment(hNode) {
    var level, str;
    // --- Retain comments
    ({str, level} = hNode);
    return indented(str, level, this.oneIndent);
  }

  // ..........................................................
  visitCmd(hNode) {
    var argstr, cmd, code, level, lineNum, srcLevel, uobj;
    debug("enter CieloToCoffeeMapper.visitCmd()", hNode);
    ({uobj, srcLevel, level, lineNum} = hNode);
    ({cmd, argstr} = uobj);
    switch (cmd) {
      case 'reactive':
        // --- This allows either a statement on the same line
        //     OR following indented text
        //     but not both
        code = this.getCmdText(hNode);
        return arrayToBlock([indented('$:', level), indented(code, level)]);
      default:
        super.visitCmd(hNode);
    }
    debug("return undef from CieloToCoffeeMapper.visitCmd()");
    return undef;
  }

};

// ---------------------------------------------------------------------------
export var CieloToJSMapper = class CieloToJSMapper extends CieloToCoffeeMapper {
  finalizeBlock(coffeeCode) {
    var err, jsCode, lImports, lNeededSymbols, stmt;
    debug("enter CieloToJSMapper.finalizeBlock()", coffeeCode);
    lNeededSymbols = getNeededSymbols(coffeeCode);
    debug(`${lNeededSymbols.length} needed symbols`, lNeededSymbols);
    try {
      jsCode = coffeeCodeToJS(coffeeCode, this.source, {
        bare: true,
        header: false
      });
      debug("jsCode", jsCode);
    } catch (error1) {
      err = error1;
      croak(err, "Original Code", coffeeCode);
    }
    if (nonEmpty(lNeededSymbols)) {
      // --- Prepend needed imports
      lImports = buildImportList(lNeededSymbols, this.source);
      debug("lImports", lImports);
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
    }
    debug("return from CieloToJSMapper.finalizeBlock()", jsCode);
    return jsCode;
  }

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
    jsCode = map(srcPath, cieloCode, CieloToJSMapper);
    barf(destPath, jsCode);
  }
};
