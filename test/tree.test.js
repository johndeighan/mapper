// Generated by CoffeeScript 2.5.1
// tree.test.coffee
var TreeTester, simple, tester;

import {
  log,
  undef,
  setUnitTesting,
  escapeStr
} from '@jdeighan/coffee-utils';

import {
  UnitTester
} from '@jdeighan/coffee-utils/test';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  taml
} from '@jdeighan/string-input/convert';

import {
  TreeWalker,
  TreeStringifier
} from '@jdeighan/string-input/tree';

setUnitTesting(true);

simple = new UnitTester();

// ---------------------------------------------------------------------------
TreeTester = class TreeTester extends UnitTester {
  transformValue(tree) {
    var str, stringifier;
    debug("enter transformValue()");
    debug(tree, "TREE:");
    stringifier = new TreeStringifier(tree);
    str = stringifier.get();
    debug(`return '${escapeStr(str)}' from tansformValue()`);
    return str;
  }

  normalize(str) {
    return str; // disable normalize()
  }

};

tester = new TreeTester();

// ---------------------------------------------------------------------------
(function() {
  var tree;
  tree = taml(`---
-
	name: John
	age: 68
	body:
		-
			name: Judy
			age: 24
		-
			name: Bob
			age: 34
-
	name: Lewis
	age: 40`);
  return tester.equal(49, tree, `{"name":"John","age":68}
	{"name":"Judy","age":24}
	{"name":"Bob","age":34}
{"name":"Lewis","age":40}`);
})();

// ---------------------------------------------------------------------------
