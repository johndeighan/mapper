// Generated by CoffeeScript 2.5.1
// PLLParser.test.coffee
var GatherTester, simple, tester;

import {
  strict as assert
} from 'assert';

import {
  undef,
  error,
  warn,
  croak
} from '@jdeighan/coffee-utils';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  UnitTester
} from '@jdeighan/coffee-utils/test';

import {
  PLLParser
} from '@jdeighan/string-input';

simple = new UnitTester();

// ---------------------------------------------------------------------------
GatherTester = class GatherTester extends UnitTester {
  transformValue(oInput) {
    assert(oInput instanceof PLLParser, "oInput should be a PLLParser object");
    return oInput.getAll();
  }

  normalize(str) {
    return str;
  }

};

tester = new GatherTester();

// ---------------------------------------------------------------------------
tester.equal(30, new PLLParser(`line 1
line 2
	line 3`), [[0, 1, 'line 1'], [0, 2, 'line 2'], [1, 3, 'line 3']]);

// ---------------------------------------------------------------------------
tester.equal(30, new PLLParser(`line 1
	line 2
		line 3`), [[0, 1, 'line 1'], [1, 2, 'line 2'], [2, 3, 'line 3']]);

// ---------------------------------------------------------------------------
// Test extending PLLParser
(function() {
  var EnvParser, parser, tree;
  EnvParser = class EnvParser extends PLLParser {
    mapNode(line) {
      var _, lMatches, left, right;
      if ((lMatches = line.match(/^\s*([A-Za-z]+)\s*=\s*([A-Za-z0-9]+)\s*$/))) {
        [_, left, right] = lMatches;
        return [left, right];
      } else {
        return croak("Bad line in EnvParser");
      }
    }

  };
  parser = new EnvParser(`name = John
	last = Deighan
age = 68
town = Blacksburg`);
  tree = parser.getTree();
  //	log "TREE", tree
  return simple.equal(79, tree, [
    {
      lineNum: 1,
      node: ['name',
    'John'],
      body: [
        {
          lineNum: 2,
          node: ['last',
        'Deighan']
        }
      ]
    },
    {
      lineNum: 3,
      node: ['age',
    '68']
    },
    {
      lineNum: 4,
      node: ['town',
    'Blacksburg']
    }
  ]);
})();