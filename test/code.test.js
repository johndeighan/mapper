// Generated by CoffeeScript 2.6.0
// code.test.coffee
var dumpfile, filepath, simple, testDir;

import {
  strict as assert
} from 'assert';

import {
  undef,
  isString,
  isHash,
  isEmpty,
  nonEmpty,
  arrayToString,
  stringToArray,
  sep_dash,
  sep_eq
} from '@jdeighan/coffee-utils';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  indented
} from '@jdeighan/coffee-utils/indent';

import {
  mydir,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  UnitTester
} from '@jdeighan/coffee-utils/test';

import {
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  forEachLine,
  forEachBlock,
  forEachSetOfBlocks
} from '@jdeighan/coffee-utils/block';

import {
  getNeededImports
} from '@jdeighan/string-input/coffee';

testDir = mydir(import.meta.url);

filepath = mkpath(testDir, 'code.test.txt');

simple = new UnitTester();

dumpfile = "c:/Users/johnd/string-input/test/ast.txt";

// ----------------------------------------------------------------------------
(async function() {
  var callback, expImports, hOptions, i, lImports, lTests, len, lineNum, results, src;
  lTests = [];
  callback = function(lBlocks, lineNum) {
    var doDebug, expImports, lMatches, src;
    [src, expImports] = lBlocks;
    if (src) {
      if (lMatches = src.match(/^\*(\*?)\s*(.*)$/s)) { // an asterisk
        // possible 2nd asterisk
        // skip any whitespace
        // capture the real source string
        [doDebug, src] = lMatches;
        if (doDebug) {
          lTests.push([-(100000 + lineNum), src, expImports]);
        } else {
          lTests.push([-lineNum, src, expImports]);
        }
      } else {
        lTests.push([lineNum, ...lBlocks]);
      }
    }
  };
  await forEachSetOfBlocks(filepath, callback);
  results = [];
  for (i = 0, len = lTests.length; i < len; i++) {
    [lineNum, src, expImports] = lTests[i];
    hOptions = {};
    if (lineNum < 0) {
      hOptions.dumpfile = dumpfile;
    }
    lImports = getNeededImports(src, hOptions);
    results.push(simple.equal(lineNum, lImports, stringToArray(expImports)));
  }
  return results;
})();

// ----------------------------------------------------------------------------
//		# --- embed the code in an IIFE
//		src = """
//			(() ->
//			#{indented(src, 1)}
//				)()
//			"""
//		lImports2 = getNeededImports(src)
//		simple.equal lineNum, lImports2, stringToArray(expImports)
