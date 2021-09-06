// Generated by CoffeeScript 2.5.1
// code.test.coffee
var dumpfile, filepath, simple, testDir;

import {
  strict as assert
} from 'assert';

import {
  undef,
  say,
  isString,
  isHash,
  isEmpty,
  nonEmpty,
  setUnitTesting,
  arrayToString,
  escapeStr,
  sep_dash,
  sep_eq
} from '@jdeighan/coffee-utils';

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
  forEachLine,
  forEachBlock,
  forEachSetOfBlocks
} from '@jdeighan/coffee-utils/block';

import {
  getMissingSymbols,
  getNeededImports,
  getAvailSymbols
} from '@jdeighan/string-input/code';

testDir = mydir(import.meta.url);

filepath = mkpath(testDir, 'code.test.txt');

simple = new UnitTester();

dumpfile = "c:/Users/johnd/string-input/test/ast.txt";

// ----------------------------------------------------------------------------
(async function() {
  var callback, expImports, hOptions, i, lTests, len, lineNum, results, src;
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
    simple.equal(lineNum, getNeededImports(src, hOptions), expImports);
    // --- embed the code in an IIFE
    src = `(() ->
${indented(src, 1)}
	)()`;
    results.push(simple.equal(lineNum, getNeededImports(src), expImports));
  }
  return results;
})();

// ----------------------------------------------------------------------------
