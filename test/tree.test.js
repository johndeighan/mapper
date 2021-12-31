// Generated by CoffeeScript 2.6.1
// tree.test.coffee
var TreeTester, simple, tester;

import {
  undef,
  oneline
} from '@jdeighan/coffee-utils';

import {
  UnitTester
} from '@jdeighan/coffee-utils/test';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  taml
} from '@jdeighan/string-input/taml';

import {
  TreeWalker,
  TreeStringifier
} from '@jdeighan/string-input/tree';

simple = new UnitTester();

// ---------------------------------------------------------------------------
TreeTester = class TreeTester extends UnitTester {
  transformValue(tree) {
    var str, stringifier;
    debug("enter transformValue()");
    debug("TREE", tree);
    stringifier = new TreeStringifier(tree);
    str = stringifier.get();
    debug(`return ${oneline(str)} from transformValue()`);
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
