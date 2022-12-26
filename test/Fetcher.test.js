// Generated by CoffeeScript 2.7.0
  // Fetcher.test.coffee
import {
  spaces
} from '@jdeighan/base-utils/utils';

import {
  setDebugging
} from '@jdeighan/base-utils/debug';

import {
  utest,
  UnitTester
} from '@jdeighan/unit-tester';

import {
  undef,
  defined
} from '@jdeighan/coffee-utils';

import {
  toArray,
  toBlock
} from '@jdeighan/coffee-utils/block';

import {
  Fetcher
} from '@jdeighan/mapper/fetcher';

// ---------------------------------------------------------------------------
// --- Fetcher should:
//        ✓ handle any iterable
//        ✓ remove trailing whitespace
//        ✓ handle extension lines
//        ✓ stop at __END__
//        ✓ implement @sourceInfoStr()
//        ✓ handle either spaces or TABs as indentation
//        ✓ implement generator all(stopperFunc)
//        ✓ implement getBlock(stopperFunc)
//        ✓ allow override of extSep()
//        ✓ allow override of finalizeBlock()
// ---------------------------------------------------------------------------
(function() {
  var MyTester, gen, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var fetcher, hNode, lLines;
      fetcher = new Fetcher(hInput);
      lLines = [];
      while (defined(hNode = fetcher.fetch())) {
        lLines.push(`${hNode.level} ${hNode.str}`);
      }
      return toBlock(lLines);
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  tester.equal(41, `abc
def`, `0 abc
0 def`);
  // ----------------------------------------------------------
  gen = function*() {
    yield 'abc';
    yield 'def';
  };
  tester.equal(56, gen(), `0 abc
0 def`);
  // ----------------------------------------------------------
  tester.equal(63, ['abc  ', 'def\t\t'], "0 abc\n0 def");
  // ----------------------------------------------------------
  // NOTE: Our output does not take level into account
  tester.equal(68, `abc
	def
ghi`, `0 abc
1 def
0 ghi`);
  // ----------------------------------------------------------
  tester.equal(80, `abc
		def
ghi`, `0 abc def
0 ghi`);
  // ----------------------------------------------------------
  tester.equal(91, `abc
def
__END__
ghi`, `0 abc
0 def`);
  // ----------------------------------------------------------
  tester.equal(103, ["abc", "def"], `0 abc
0 def`);
  // ----------------------------------------------------------
  // --- test TABs
  tester.equal(111, ["abc", "\tdef", "\t\tghi"], `0 abc
1 def
2 ghi`);
  // ----------------------------------------------------------
  // --- test spaces
  return tester.equal(120, ["abc", spaces(3) + "def", spaces(6) + "ghi"], `0 abc
1 def
2 ghi`);
})();

// ---------------------------------------------------------------------------
(function() {
  var fetcher, node1, node2, node3;
  fetcher = new Fetcher(`abc
		def
		ghi
jkl`);
  node1 = fetcher.fetch();
  utest.like(141, node1, {
    str: 'abc def ghi',
    lineNum: 1,
    source: "<unknown>/1"
  });
  node2 = fetcher.fetch();
  utest.like(150, node2, {
    str: 'jkl',
    lineNum: 4,
    source: "<unknown>/4"
  });
  node3 = fetcher.fetch();
  return utest.equal(157, node3, undef);
})();

// ---------------------------------------------------------------------------
(function() {
  var fetcher, node1;
  fetcher = new Fetcher({
    source: 'file.coffee',
    content: `abc
		def
		ghi
jkl`
  });
  node1 = fetcher.fetch();
  return utest.like(175, node1, {
    str: 'abc def ghi',
    lineNum: 1,
    source: "file.coffee/1"
  });
})();

// ---------------------------------------------------------------------------
// --- test all()
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var fetcher;
      fetcher = new Fetcher(hInput);
      return Array.from(fetcher.all());
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  tester.like(197, `abc
def`, [
    {
      str: 'abc',
      level: 0
    },
    {
      str: 'def',
      level: 0
    }
  ]);
  // ----------------------------------------------------------
  tester.like(207, `abc
	def
ghi`, [
    {
      str: 'abc',
      level: 0
    },
    {
      str: 'def',
      level: 1
    },
    {
      str: 'ghi',
      level: 0
    }
  ]);
  // ----------------------------------------------------------
  return tester.like(219, `abc
		def
ghi`, [
    {
      str: 'abc def',
      level: 0
    },
    {
      str: 'ghi',
      level: 0
    }
  ]);
})();

// ---------------------------------------------------------------------------
// --- test all() with a stopper func
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var fetcher, stopperFunc;
      fetcher = new Fetcher(hInput);
      stopperFunc = (h) => {
        return h.str === 'STOP';
      };
      return Array.from(fetcher.all(stopperFunc));
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  tester.like(246, `abc
STOP
def`, [
    {
      str: 'abc',
      level: 0
    }
  ]);
  // ----------------------------------------------------------
  tester.like(256, `abc
	def
STOP
ghi`, [
    {
      str: 'abc',
      level: 0
    },
    {
      str: 'def',
      level: 1
    }
  ]);
  // ----------------------------------------------------------
  return tester.like(268, `abc
		def
STOP
ghi`, [
    {
      str: 'abc def',
      level: 0
    }
  ]);
})();

// ---------------------------------------------------------------------------
// --- test getBlock()
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var fetcher;
      fetcher = new Fetcher(hInput);
      return fetcher.getBlock();
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  tester.equal(294, `abc
def`, `abc
def`);
  // ----------------------------------------------------------
  tester.equal(304, `abc
	def
ghi`, `abc
	def
ghi`);
  // ----------------------------------------------------------
  return tester.equal(316, `abc
		def
ghi`, `abc def
ghi`);
})();

// ---------------------------------------------------------------------------
// --- test getBlock() with a stopper func
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var fetcher, stopperFunc;
      fetcher = new Fetcher(hInput);
      stopperFunc = (h) => {
        return h.str === 'STOP';
      };
      return fetcher.getBlock(stopperFunc);
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  tester.equal(343, `abc
def`, `abc
def`);
  // ----------------------------------------------------------
  tester.equal(353, `abc
	def
STOP
ghi`, `abc
	def`);
  // ----------------------------------------------------------
  return tester.equal(365, `abc
		def
STOP
ghi`, `abc def`);
})();

// ---------------------------------------------------------------------------
(function() {
  var MyTester, ZhFetcher, tester;
  // --- Don't include a space char when adding extension lines
  ZhFetcher = class ZhFetcher extends Fetcher {
    extSep(str, nextStr) {
      return '';
    }

  };
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var fetcher, stopperFunc;
      fetcher = new ZhFetcher(hInput);
      stopperFunc = (h) => {
        return h.str === 'STOP';
      };
      return fetcher.getBlock(stopperFunc);
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  return tester.equal(398, `你好
		约翰
STOP
我在这里`, `你好约翰`);
})();

// ---------------------------------------------------------------------------
(function() {
  var CapFetcher, MyTester, tester;
  // --- capitalize all text returned by getBlock()
  CapFetcher = class CapFetcher extends Fetcher {
    finalizeBlock(block) {
      return block.toUpperCase();
    }

  };
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var fetcher, stopperFunc;
      fetcher = new CapFetcher(hInput);
      stopperFunc = (h) => {
        return h.str === 'STOP';
      };
      return fetcher.getBlock(stopperFunc);
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  return tester.equal(431, `abc
		def
STOP
ghi`, `ABC DEF`);
})();
