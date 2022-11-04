// Generated by CoffeeScript 2.7.0
  // cielo.coffee
import {
  LOG,
  assert,
  croak
} from '@jdeighan/exceptions';

import {
  dbg,
  dbgEnter,
  dbgReturn
} from '@jdeighan/exceptions/debug';

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
  indentLevel,
  indented,
  isUndented,
  splitLine
} from '@jdeighan/coffee-utils/indent';

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
  TreeMapper
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
export var CieloToCoffeeMapper = class CieloToCoffeeMapper extends TreeMapper {
  mapComment(hNode) {
    var level, str;
    // --- Retain comments
    ({str, level} = hNode);
    return indented(str, level, this.oneIndent);
  }

  // ..........................................................
  visitCmd(hNode) {
    var argstr, cmd, code, level, lineNum, result, srcLevel, uobj;
    dbgEnter("CieloToCoffeeMapper.visitCmd", hNode);
    ({uobj, srcLevel, level, lineNum} = hNode);
    ({cmd, argstr} = uobj);
    switch (cmd) {
      case 'reactive':
        // --- This allows either a statement on the same line
        //     OR following indented text
        //     but not both
        code = this.containedText(hNode, argstr);
        dbg('code', code);
        if (code === argstr) {
          result = arrayToBlock([indented('# |||| $:', level), indented(code, level)]);
        } else {
          result = arrayToBlock([indented('# |||| $: {', level), indented(code, level), indented('# |||| }', level)]);
        }
        dbgReturn("CieloToCoffeeMapper.visitCmd", result);
        return result;
      default:
        super.visitCmd(hNode);
    }
    dbgReturn("CieloToCoffeeMapper.visitCmd", undef);
    return undef;
  }

};

// ---------------------------------------------------------------------------
export var CieloToJSMapper = class CieloToJSMapper extends CieloToCoffeeMapper {
  finalizeBlock(coffeeCode) {
    var err, jsCode, lImports, lNeededSymbols, stmt;
    dbgEnter("CieloToJSMapper.finalizeBlock", coffeeCode);
    lNeededSymbols = getNeededSymbols(coffeeCode);
    dbg(`${lNeededSymbols.length} needed symbols`, lNeededSymbols);
    try {
      jsCode = coffeeCodeToJS(coffeeCode, this.source, {
        bare: true,
        header: false
      });
      dbg("jsCode", jsCode);
    } catch (error) {
      err = error;
      croak(err, "Original Code", coffeeCode);
    }
    if (nonEmpty(lNeededSymbols)) {
      // --- Prepend needed imports
      lImports = buildImportList(lNeededSymbols, this.source);
      dbg("lImports", lImports);
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
    dbgReturn("CieloToJSMapper.finalizeBlock", jsCode);
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
    jsCode = map(srcPath, cieloCode, CieloToJSMapper);
    barf(destPath, jsCode);
  }
};
