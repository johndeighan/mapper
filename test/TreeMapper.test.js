// Generated by CoffeeScript 2.7.0
// TreeMapper.test.coffee
var GatherTester, simple, tester;

import assert from 'assert';

import {
  UnitTesterNorm,
  UnitTester
} from '@jdeighan/unit-tester';

import {
  undef,
  error,
  warn,
  croak,
  isString
} from '@jdeighan/coffee-utils';

import {
  log
} from '@jdeighan/coffee-utils/log';

import {
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  TreeMapper
} from '@jdeighan/mapper/tree';

simple = new UnitTesterNorm();

// ---------------------------------------------------------------------------
GatherTester = class GatherTester extends UnitTester {
  transformValue(input) {
    var oInput;
    if (isString(input)) {
      oInput = new TreeMapper(import.meta.url, input);
    } else if (input instanceof TreeMapper) {
      oInput = input;
    } else {
      croak(`GatherTester(): Invalid input ${typeof input}`);
    }
    return oInput.getAllPairs();
  }

};

tester = new GatherTester();

// ---------------------------------------------------------------------------
tester.equal(31, `line 1
line 2
	line 3`, [[0, 1, 'line 1'], [0, 2, 'line 2'], [1, 3, 'line 3']]);

// ---------------------------------------------------------------------------
tester.equal(43, `line 1
	line 2
		line 3`, [[0, 1, 'line 1'], [1, 2, 'line 2'], [2, 3, 'line 3']]);

// ---------------------------------------------------------------------------
// Test extending TreeMapper
(function() {
  var EnvMapper, parser, tree;
  EnvMapper = class EnvMapper extends TreeMapper {
    mapNode(line) {
      var _, lMatches, left, right;
      if ((lMatches = line.match(/^\s*([A-Za-z]+)\s*=\s*([A-Za-z0-9]+)\s*$/))) {
        [_, left, right] = lMatches;
        return [left, right];
      } else {
        return croak("Bad line in EnvMapper");
      }
    }

  };
  parser = new EnvMapper(import.meta.url, `name = John
	last = Deighan
age = 68
town = Blacksburg`);
  tree = parser.getTree();
  return simple.equal(84, tree, [
    {
      lineNum: 1,
      node: ['name',
    'John'],
      subtree: [
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

// ---------------------------------------------------------------------------
// Test extending TreeMapper when mapNode() sometimes returns undef
(function() {
  var EnvMapper, parser, tree;
  EnvMapper = class EnvMapper extends TreeMapper {
    mapNode(line) {
      var _, lMatches, left, right;
      if ((lMatches = line.match(/^\s*([A-Za-z]+)\s*=\s*([A-Za-z0-9]+)\s*$/))) {
        [_, left, right] = lMatches;
        if (left === 'name') {
          return undef;
        }
        return right;
      } else {
        return croak("Bad line in EnvMapper");
      }
    }

  };
  parser = new EnvMapper(import.meta.url, `name = John
	last = Deighan
age = 68
town = Blacksburg`);
  tree = parser.getTree();
  return simple.equal(127, tree, [
    {
      lineNum: 3,
      node: '68'
    },
    {
      lineNum: 4,
      node: 'Blacksburg'
    }
  ]);
})();