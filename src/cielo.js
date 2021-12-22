// Generated by CoffeeScript 2.6.1
// cielo.coffee
var CieloMapper;

import {
  assert,
  say,
  isString,
  isArray
} from '@jdeighan/coffee-utils';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  indentLevel
} from '@jdeighan/coffee-utils/indent';

import {
  joinBlocks
} from '@jdeighan/coffee-utils/block';

import {
  withExt,
  newerDestFileExists,
  slurp,
  shortenPath
} from '@jdeighan/coffee-utils/fs';

import {
  SmartInput
} from '@jdeighan/string-input';

import {
  getNeededSymbols,
  buildImportList
} from '@jdeighan/string-input/coffee';

// ---------------------------------------------------------------------------
CieloMapper = class CieloMapper extends SmartInput {
  // --- retain empty lines & comments
  handleEmptyLine(level) {
    // --- keep empty lines
    return '';
  }

  handleComment(line, level) {
    // --- keep comments
    return line;
  }

};

// ---------------------------------------------------------------------------
// --- Features:
//        1. KEEP blank lines and comments
//        2. #include <file>
//        3. replace {{FILE}} and {{LINE}}
//        4. handle continuation lines
//        5. handle HEREDOC
//        6. stop on __END__
//        7. add auto-imports
export var brewCielo = function(...lBlocks) {
  var code, coffeeCode, i, importStmts, j, k, lAllNeededSymbols, lNeededSymbols, lNewBlocks, len, len1, oInput, symbol;
  // --- convert blocks of cielo code to blocks of coffee code
  //     also provides needed import statements
  debug("enter brewCielo()");
  lAllNeededSymbols = [];
  lNewBlocks = [];
  for (i = j = 0, len = lBlocks.length; j < len; i = ++j) {
    code = lBlocks[i];
    assert(indentLevel(code) === 0, `brewCielo(): code ${i} has indent`);
    // --- CieloMapper handles the above conversions
    oInput = new CieloMapper(code);
    coffeeCode = oInput.getAllText();
    // --- will be unique
    lNeededSymbols = getNeededSymbols(coffeeCode);
    for (k = 0, len1 = lNeededSymbols.length; k < len1; k++) {
      symbol = lNeededSymbols[k];
      if (!lAllNeededSymbols.includes(symbol)) {
        lAllNeededSymbols.push(symbol);
      }
    }
    lNewBlocks.push(coffeeCode);
    debug('CIELO CODE', code);
    debug('lNeededSymbols', lNeededSymbols);
    debug('COFFEE CODE', coffeeCode);
  }
  importStmts = buildImportList(lAllNeededSymbols).join("\n");
  debug('importStmts', importStmts);
  debug("return from brewCielo()");
  return {
    code: lNewBlocks,
    lAllNeededSymbols,
    importStmts
  };
};

// ---------------------------------------------------------------------------
export var checkCieloHash = function(hCielo, maxBlocks = 1) {
  assert(hCielo != null, "checkCieloHash(): empty hCielo");
  assert(hCielo.hasOwnProperty('code'), "checkCieloHash(): No key 'code'");
  assert(hCielo.code.length <= maxBlocks, "checkCieloHash(): Too many blocks");
  assert(isString(hCielo.code[0]), "checkCieloHash(): code[0] not a string");
  if (hCielo.hasOwnProperty('importStmts')) {
    assert(isString(hCielo.importStmts), "checkCieloHash(): 'importStmts' not a string");
  }
};

// ---------------------------------------------------------------------------
export var buildCieloBlock = function(hCielo) {
  checkCieloHash(hCielo);
  return joinBlocks(hCielo.importStmts, hCielo.code[0]);
};

// ---------------------------------------------------------------------------
export var brewCieloStr = function(str) {
  var hCielo;
  // --- cielo => coffee
  hCielo = brewCielo(str);
  return buildCieloBlock(hCielo);
};

// ---------------------------------------------------------------------------
export var output = function(code, srcPath, destPath, doLog = false) {
  var err;
  try {
    barf(destPath, code);
  } catch (error) {
    err = error;
    log(`output(): ERROR: ${err.message}`);
  }
  if (doLog) {
    log(`   => ${shortenPath(destPath)}`);
  }
};

// ---------------------------------------------------------------------------
export var brewCieloFile = function(srcPath) {
  var code, destPath, str;
  // --- cielo => coffee
  destPath = withExt(srcPath, '.coffee');
  if (!newerDestFileExists(srcPath, destPath)) {
    str = slurp(srcPath);
    code = brewCieloStr(str);
    output(code, srcPath, destPath);
  }
};
