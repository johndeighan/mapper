// Generated by CoffeeScript 2.7.0
// TreeMapper.test.coffee
var HtmlMapper, WalkTester, walkTester;

import {
  LOG,
  LOGVALUE,
  assert,
  croak,
  setDebugging,
  fromTAML
} from '@jdeighan/exceptions';

import {
  dbg,
  dbgEnter,
  dbgReturn
} from '@jdeighan/exceptions/debug';

import {
  UnitTester,
  UnitTesterNorm,
  utest
} from '@jdeighan/unit-tester';

import {
  undef,
  pass,
  OL,
  defined,
  isEmpty,
  nonEmpty,
  isString,
  isArray
} from '@jdeighan/coffee-utils';

import {
  indentLevel,
  undented,
  splitLine,
  indented
} from '@jdeighan/coffee-utils/indent';

import {
  mydir,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  arrayToBlock,
  blockToArray
} from '@jdeighan/coffee-utils/block';

import {
  map
} from '@jdeighan/mapper';

import {
  TreeMapper,
  trace
} from '@jdeighan/mapper/tree';

import {
  SimpleMarkDownMapper
} from '@jdeighan/mapper/markdown';

/*
	class TreeMapper should handle the following:
		- remove empty lines and comments
		- extension lines
		- can override @mapNode() - used in @getAll()
		- call @walk() to walk the tree
		- can override beginLevel(), visit(), endVisit(), endLevel()
*/
// ---------------------------------------------------------------------------
//             BEGIN allMapped
// ---------------------------------------------------------------------------
(function() {
  var MapTester, mapTester;
  MapTester = class MapTester extends UnitTester {
    transformValue(block) {
      var lUserObjects, ref, uobj, walker;
      walker = new TreeMapper(import.meta.url, block);
      lUserObjects = [];
      ref = walker.allMapped();
      for (uobj of ref) {
        lUserObjects.push(uobj);
      }
      assert(isArray(lUserObjects), `lUserObjects is ${OL(lUserObjects)}`);
      return lUserObjects;
    }

  };
  mapTester = new MapTester();
  // ------------------------------------------------------------------------
  // --- remove comments and blank lines
  //     create user object from utest line
  mapTester.like(53, `# --- comment, followed by blank line xxx

abc`, [
    {
      str: 'abc',
      level: 0
    }
  ]);
  // ------------------------------------------------------------------------
  // --- remove comments and blank lines
  //     create user object from utest line
  mapTester.like(65, `# --- comment, followed by blank line

abc

# --- this should not be removed

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
  // ------------------------------------------------------------------------
  // --- level
  return mapTester.like(81, `abc
	def
		ghi
	uvw
xyz`, [
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
      level: 2
    },
    {
      str: 'uvw',
      level: 1
    },
    {
      str: 'xyz',
      level: 0
    }
  ]);
})();

// ---------------------------------------------------------------------------
// Create a more compact mapTester
(function() {
  var MapTester, mapTester;
  MapTester = class MapTester extends UnitTester {
    constructor() {
      super();
      this.debug = false;
    }

    transformValue(block) {
      var lUserObjects, ref, uobj, walker;
      walker = new TreeMapper(import.meta.url, block);
      lUserObjects = [];
      ref = walker.allMapped();
      for (uobj of ref) {
        lUserObjects.push(uobj);
      }
      if (this.debug) {
        LOG('lUserObjects', lUserObjects);
      }
      assert(isArray(lUserObjects), `lUserObjects is ${OL(lUserObjects)}`);
      return lUserObjects;
    }

    getUserObj(line) {
      var level, pos, str;
      pos = line.indexOf(' ');
      assert(pos > 0, `Missing 1st space char in ${OL(line)}`);
      level = parseInt(line.substring(0, pos));
      str = line.substring(pos + 1).replace(/\\N/g, '\n').replace(/\\T/g, '\t');
      if (str[0] === '{') {
        str = eval_expr(str);
      }
      return {str, level};
    }

    transformExpected(block) {
      var i, lExpected, len, line, ref;
      lExpected = [];
      ref = blockToArray(block);
      for (i = 0, len = ref.length; i < len; i++) {
        line = ref[i];
        if (this.debug) {
          LOG('line', line);
        }
        lExpected.push(this.getUserObj(line));
      }
      if (this.debug) {
        LOG('lExpected', lExpected);
      }
      assert(isArray(lExpected), `lExpected is ${OL(lExpected)}`);
      return lExpected;
    }

    doDebug(flag = true) {
      this.debug = flag;
    }

  };
  mapTester = new MapTester();
  // ------------------------------------------------------------------------
  mapTester.like(151, `abc
	def
		ghi`, `0 abc
1 def
2 ghi`);
  // ------------------------------------------------------------------------
  // --- const replacement
  mapTester.like(164, `#define name John Deighan
abc
__name__`, `0 abc
0 John Deighan`);
  // ------------------------------------------------------------------------
  // --- extension lines
  mapTester.like(176, `abc
		&& def
		&& ghi
xyz`, `0 abc && def && ghi
0 xyz`);
  // ------------------------------------------------------------------------
  // --- HEREDOC handling - block (default)
  mapTester.like(189, `func(<<<)
	abc
	def

xyz`, `0 func("abc\\ndef")
0 xyz`);
  // ------------------------------------------------------------------------
  // --- HEREDOC handling - block (explicit)
  mapTester.like(203, `func(<<<)
	===
	abc
	def

xyz`, `0 func("abc\\ndef")
0 xyz`);
  // ------------------------------------------------------------------------
  // --- HEREDOC handling - oneline
  mapTester.like(218, `func(<<<)
	...
	abc
	def

xyz`, `0 func("abc def")
0 xyz`);
  // ------------------------------------------------------------------------
  // --- HEREDOC handling - oneline
  mapTester.like(233, `func(<<<)
	...abc
		def

xyz`, `0 func("abc def")
0 xyz`);
  // ------------------------------------------------------------------------
  // --- HEREDOC handling - TAML
  mapTester.like(247, `func(<<<)
	---
	- abc
	- def

xyz`, `0 func(["abc","def"])
0 xyz`);
  // ------------------------------------------------------------------------
  // --- HEREDOC handling - function
  mapTester.like(262, `handleClick(<<<)
	(event) ->
		event.preventDefault()
		alert 'clicked'
		return

xyz`, `0 handleClick((event) ->\\N\\Tevent.preventDefault()\\N\\Talert 'clicked'\\N\\Treturn)
0 xyz`);
  // ------------------------------------------------------------------------
  // --- using __END__
  mapTester.like(278, `abc
def
__END__
ghi
jkl`, `0 abc
0 def`);
  // ------------------------------------------------------------------------
  // ------------------------------------------------------------------------
  // --- test #ifdef with no value - value not defined
  mapTester.like(293, `#ifdef mobile
	abc
def`, `0 def`);
  // ------------------------------------------------------------------------
  // --- test #ifdef with no value - value defined
  mapTester.like(304, `#define mobile anything
#ifdef mobile
	abc
def`, `0 abc
0 def`);
  // ------------------------------------------------------------------------
  // ------------------------------------------------------------------------
  // --- test #ifdef with a value - value not defined
  mapTester.like(318, `#ifdef mobile samsung
	abc
def`, `0 def`);
  // ------------------------------------------------------------------------
  // --- test #ifdef with a value - value defined, but different
  mapTester.like(329, `#define mobile apple
#ifdef mobile samsung
	abc
def`, `0 def`);
  // ------------------------------------------------------------------------
  // --- test #ifdef with a value - value defined and same
  mapTester.like(341, `#define mobile samsung
#ifdef mobile samsung
	abc
def`, `0 abc
0 def`);
  // ------------------------------------------------------------------------
  // ------------------------------------------------------------------------
  // --- test #ifndef with no value - not defined
  mapTester.like(355, `#ifndef mobile
	abc
def`, `0 abc
0 def`);
  // ------------------------------------------------------------------------
  // --- test #ifndef with no value - defined
  mapTester.like(367, `#define mobile anything
#ifndef mobile
	abc
def`, `0 def`);
  // ------------------------------------------------------------------------
  // ------------------------------------------------------------------------
  // --- test #ifndef with a value - not defined
  mapTester.like(380, `#ifndef mobile samsung
	abc
def`, `0 abc
0 def`);
  // ------------------------------------------------------------------------
  // --- test #ifndef with a value - defined, but different
  mapTester.like(392, `#define mobile apple
#ifndef mobile samsung
	abc
def`, `0 abc
0 def`);
  // ------------------------------------------------------------------------
  // --- test #ifndef with a value - defined and same
  mapTester.like(405, `#define mobile samsung
#ifndef mobile samsung
	abc
def`, `0 def`);
  // ------------------------------------------------------------------------
  // ------------------------------------------------------------------------
  // --- nested commands
  mapTester.like(418, `#define mobile samsung
#define large anything
#ifdef mobile samsung
	#ifdef large
		abc
			def`, `0 abc
1 def`);
  // --- nested commands
  mapTester.like(432, `#define mobile samsung
#define large anything
#ifndef mobile samsung
	#ifdef large
		abc`, `			`);
  // --- nested commands
  mapTester.like(443, `#define mobile samsung
#define large anything
#ifdef mobile samsung
	#ifndef large
		abc`, `			`);
  // --- nested commands
  mapTester.like(454, `#define mobile samsung
#define large anything
#ifndef mobile samsung
	#ifndef large
		abc`, `			`);
  // ----------------------------------------------------------
  // --- nested commands - every combination
  mapTester.like(466, `#define mobile samsung
#define large anything
#ifdef mobile samsung
	abc
	#ifdef large
		def
ghi`, `0 abc
0 def
0 ghi`);
  // --- nested commands - every combination
  mapTester.like(482, `#define mobile samsung
#ifdef mobile samsung
	abc
	#ifdef large
		def
ghi`, `0 abc
0 ghi`);
  // --- nested commands - every combination
  mapTester.like(496, `#define large anything
#ifdef mobile samsung
	abc
	#ifdef large
		def
ghi`, `0 ghi`);
  // --- nested commands - every combination
  return mapTester.like(509, `#ifdef mobile samsung
	abc
	#ifdef large
		def
ghi`, `0 ghi`);
})();

// ---------------------------------------------------------------------------
//             END allMapped
// ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
//             BEGIN walk
// ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
// Test TreeMapper.walk()
(function() {
  var Tester, walkTester;
  Tester = class Tester extends UnitTesterNorm {
    transformValue(block) {
      return trace(import.meta.url, block);
    }

  };
  walkTester = new Tester();
  walkTester.equal(541, `			`, `BEGIN WALK
END WALK`);
  walkTester.equal(547, `abc`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
END LEVEL 0
END WALK`);
  walkTester.equal(558, `abc
def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
VISIT     0 'def'
END VISIT 0 'def'
END LEVEL 0
END WALK`);
  walkTester.equal(572, `abc
	def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
BEGIN LEVEL 1
VISIT     1 'def'
END VISIT 1 'def'
END LEVEL 1
END VISIT 0 'abc'
END LEVEL 0
END WALK`);
  walkTester.equal(588, `# this is a unit test
abc

	def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
BEGIN LEVEL 1
VISIT     1 'def'
END VISIT 1 'def'
END LEVEL 1
END VISIT 0 'abc'
END LEVEL 0
END WALK`);
  walkTester.equal(606, `# this is a unit test
abc
__END__
	def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
END LEVEL 0
END WALK`);
  return walkTester.equal(620, `# this is a unit test
abc
		def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc˳def'
END VISIT 0 'abc˳def'
END LEVEL 0
END WALK`);
})();

// ---------------------------------------------------------------------------
//             END walk
// ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
//             BEGIN ifdef
// ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
WalkTester = class WalkTester extends UnitTesterNorm {
  transformValue(block) {
    return trace(import.meta.url, block);
  }

};

walkTester = new WalkTester();

// ..........................................................
walkTester.equal(655, `abc`, `BEGIN WALK
BEGIN LEVEL 0
VISIT       0 'abc'
END VISIT   0 'abc'
END LEVEL   0
END WALK`);

walkTester.equal(666, `abc
def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
VISIT     0 'def'
END VISIT 0 'def'
END LEVEL 0
END WALK`);

walkTester.equal(680, `abc
	def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
BEGIN LEVEL 1
VISIT     1 'def'
END VISIT 1 'def'
END LEVEL 1
END VISIT 0 'abc'
END LEVEL 0
END WALK`);

walkTester.equal(696, `abc
#ifdef NOPE
	def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
END LEVEL   0
END WALK`);

walkTester.equal(709, `abc
#ifndef NOPE
	def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
VISIT     0 'def'
END VISIT 0 'def'
END LEVEL   0
END WALK`);

walkTester.equal(724, `#define NOPE 42
abc
#ifndef NOPE
	def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
END LEVEL   0
END WALK`);

walkTester.equal(738, `#define NOPE 42
abc
#ifdef NOPE
	def`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
VISIT     0 'def'
END VISIT 0 'def'
END LEVEL   0
END WALK`);

walkTester.equal(754, `#define NOPE 42
#define name John
abc
#ifdef NOPE
	def
	#ifdef name
		ghi`, `BEGIN WALK
BEGIN LEVEL 0
VISIT     0 'abc'
END VISIT 0 'abc'
VISIT     0 'def'
END VISIT 0 'def'
VISIT     0 'ghi'
END VISIT 0 'ghi'
END LEVEL   0
END WALK`);

// ---------------------------------------------------------------------------
//             END ifdef
// ---------------------------------------------------------------------------

  // --- Test TreeMapper.get() with special lines
(function() {
  var walker;
  walker = new TreeMapper(undef, `line1
# a comment
line2

line3`);
  utest.like(789, walker.get(), {
    str: 'line1',
    level: 0,
    lineNum: 1
  });
  utest.like(794, walker.get(), {
    str: 'line2',
    level: 0,
    lineNum: 3
  });
  utest.like(799, walker.get(), {
    str: 'line3',
    level: 0,
    lineNum: 5
  });
  return utest.equal(804, walker.get(), undef);
})();

// ---------------------------------------------------------------------------
// Test TreeMapper.get()
(function() {
  var walker;
  walker = new TreeMapper(import.meta.url, `# --- a comment

abc
	def
		ghi`);
  utest.like(820, walker.get(), {
    str: 'abc',
    level: 0
  });
  utest.like(824, walker.get(), {
    str: 'def',
    level: 1
  });
  utest.like(828, walker.get(), {
    str: 'ghi',
    level: 2
  });
  return utest.equal(832, walker.get(), undef);
})();

// ---------------------------------------------------------------------------
// Test __END__ and extension lines with TreeMapper.get()
(function() {
  var walker;
  walker = new TreeMapper(import.meta.url, `abc
		def
	ghi
__END__
		ghi`);
  // --- get() should return {uobj, level}
  utest.like(849, walker.get(), {
    str: 'abc def',
    level: 0
  });
  utest.like(853, walker.get(), {
    str: 'ghi',
    level: 1
  });
  return utest.equal(857, walker.get(), undef);
})();

// ---------------------------------------------------------------------------
// __END__ only works with no identation
(function() {
  return utest.fails(864, function() {
    return map(import.meta.url, `abc
		def
	ghi
	__END__
		ghi`, TreeMapper);
  });
})();

// ---------------------------------------------------------------------------
(function() {
  var Tester, treeTester;
  Tester = class Tester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, TreeMapper);
    }

  };
  treeTester = new Tester();
  // ---------------------------------------------------------------------------
  // --- Test basic reading till EOF
  treeTester.equal(888, `abc
def`, `abc
def`);
  treeTester.equal(896, `abc

def`, `abc
def`);
  return treeTester.equal(905, `# --- a comment
p
	margin: 0
	span
		color: red`, `p
	margin: 0
	span
		color: red`);
})();

// ---------------------------------------------------------------------------
// Test empty line handling
(function() {
  var MyTester, MyWalker, block, treeTester;
  MyWalker = class MyWalker extends TreeMapper {
    // --- This removes blank lines
    mapEmptyLine() {
      dbg("in MyWalker.mapEmptyLine()");
      return undef;
    }

  };
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, MyWalker);
    }

  };
  treeTester = new MyTester();
  // ..........................................................
  block = `abc

def`;
  utest.equal(950, map(import.meta.url, block, MyWalker), `abc
def`);
  return treeTester.equal(955, block, `abc
def`);
})();

// ---------------------------------------------------------------------------
// Test comment handling
(function() {
  var MyTester, MyWalker, block, treeTester;
  MyWalker = class MyWalker extends TreeMapper {
    isComment(hNode) {
      // --- comments start with //
      return hNode.str.match(/^\/\//);
    }

    mapComment(hNode) {
      // --- remove comments
      return undef;
    }

  };
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, MyWalker);
    }

  };
  treeTester = new MyTester();
  // ..........................................................
  block = `// a comment - should be removed
//also a comment
# not a comment
abc
def`;
  utest.equal(998, map(import.meta.url, block, MyWalker), `# not a comment
abc
def`);
  return treeTester.equal(1004, block, `# not a comment
abc
def`);
})();

// ---------------------------------------------------------------------------
// Test command handling
(function() {
  var MyTester, MyWalker, block, treeTester;
  MyWalker = class MyWalker extends TreeMapper {
    isCmd(hNode) {
      var lMatches;
      // --- commands consist of '-' + one whitespace char + word
      if ((lMatches = hNode.str.match(/^-\s(\w+)$/))) {
        hNode.uobj = {
          cmd: lMatches[1],
          argstr: ''
        };
        return true;
      } else {
        return false;
      }
    }

    // .......................................................
    mapCmd(hNode) {
      // --- NOTE: this disables handling all commands,
      //           i.e. #define, etc.
      // --- Returning any non-undef value prevents discarding hNode
      //     and sets key uobj to the returned value
      return hNode.uobj;
    }

    // .......................................................
    visitCmd(hNode) {
      var result;
      dbgEnter("MyWalker.visitCmd");
      result = `COMMAND: ${hNode.uobj.cmd}`;
      dbgReturn("MyWalker.visitCmd", result);
      return result;
    }

  };
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, MyWalker);
    }

  };
  treeTester = new MyTester();
  // ..........................................................
  block = `# remove this

abc
- command
def`;
  return treeTester.equal(1067, block, `abc
COMMAND: command
def`);
})();

// ---------------------------------------------------------------------------
// try retaining indentation for mapped lines
(function() {
  var MyTester, MyWalker, treeTester;
  // --- NOTE: mapNode() returns anything,
  //           or undef to ignore the line
  MyWalker = class MyWalker extends TreeMapper {
    // --- This maps all non-empty lines to the string 'x'
    //     and removes all empty lines
    mapNode(hNode) {
      var level, result, str;
      dbgEnter("mapNode", hNode);
      ({str, level} = hNode);
      if (isEmpty(str)) {
        dbgReturn("mapNode", undef);
        return undef;
      } else {
        result = indented('x', level, this.oneIndent);
        dbgReturn("mapNode", result);
        return result;
      }
    }

  };
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, MyWalker);
    }

  };
  treeTester = new MyTester();
  // ..........................................................
  return treeTester.equal(1110, `abc
	def

ghi`, `x
	x
x`);
})();

// ---------------------------------------------------------------------------
// --- Test ability to access 'this' object from a walker
//     Goal: remove not only blank lines, but also the line following
(function() {
  var MyTester, MyWalker, treeTester;
  MyWalker = class MyWalker extends TreeMapper {
    // --- Remove blank lines PLUS the line following a blank line
    mapEmptyLine(hNode) {
      var follow;
      follow = this.fetch();
      return undef; // remove empty lines
    }

  };
  
    // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, MyWalker);
    }

  };
  treeTester = new MyTester();
  // ..........................................................
  return treeTester.equal(1148, `abc

def
ghi`, `abc
ghi`);
})();

// ---------------------------------------------------------------------------
// --- Test #include
(function() {
  var MyTester, treeTester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, TreeMapper);
    }

  };
  // ..........................................................
  treeTester = new MyTester();
  return treeTester.equal(1174, `abc
	#include title.md
def`, `abc
	title
	=====
def`);
})();

// ---------------------------------------------------------------------------
// --- Test getAll()
(function() {
  var MyTester, treeTester;
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      var walker;
      walker = new TreeMapper(import.meta.url, block);
      return walker.getAll();
    }

  };
  treeTester = new MyTester();
  return treeTester.like(1203, `abc
	def
		ghi
jkl`, fromTAML(`---
-
	level: 0
	str: 'abc'
-
	level: 1
	str: 'def'
-
	level: 2
	str: 'ghi'
-
	level: 0
	str: 'jkl'`));
})();

// ---------------------------------------------------------------------------
(function() {
  var walker;
  walker = new TreeMapper(import.meta.url, `if (x == 2)
	doThis
	doThat
		then this
while (x > 2)
	--x`);
  utest.like(1239, walker.peek(), {
    level: 0,
    str: 'if (x == 2)'
  });
  utest.like(1240, walker.get(), {
    level: 0,
    str: 'if (x == 2)'
  });
  utest.like(1242, walker.peek(), {
    level: 1,
    str: 'doThis'
  });
  utest.like(1243, walker.get(), {
    level: 1,
    str: 'doThis'
  });
  utest.like(1245, walker.peek(), {
    level: 1,
    str: 'doThat'
  });
  utest.like(1246, walker.get(), {
    level: 1,
    str: 'doThat'
  });
  utest.like(1248, walker.peek(), {
    level: 2,
    str: 'then this'
  });
  utest.like(1249, walker.get(), {
    level: 2,
    str: 'then this'
  });
  utest.like(1251, walker.peek(), {
    level: 0,
    str: 'while (x > 2)'
  });
  utest.like(1252, walker.get(), {
    level: 0,
    str: 'while (x > 2)'
  });
  utest.like(1254, walker.peek(), {
    level: 1,
    str: '--x'
  });
  return utest.like(1255, walker.get(), {
    level: 1,
    str: '--x'
  });
})();

// ---------------------------------------------------------------------------
// --- Test HEREDOC
(function() {
  var MyTester, treeTester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, TreeMapper);
    }

  };
  // ..........................................................
  treeTester = new MyTester();
  treeTester.equal(1274, `abc
if x == <<<
	abc
	def

def`, `abc
if x == "abc\\ndef"
def`);
  treeTester.equal(1287, `abc
if x == <<<
	===
	abc
	def

def`, `abc
if x == "abc\\ndef"
def`);
  return treeTester.equal(1301, `abc
if x == <<<
	...
	abc
	def

def`, `abc
if x == "abc def"
def`);
})();

// ---------------------------------------------------------------------------
// --- A more complex example
HtmlMapper = class HtmlMapper extends TreeMapper {
  mapNode(hNode) {
    var _, body, hResult, lMatches, level, md, str, tag, text;
    dbgEnter("MyWalker.mapNode", hNode);
    ({str, level} = hNode);
    lMatches = str.match(/^(\S+)(?:\s+(.*))?$/); // the tag
    // some whitespace
    // everything else
    // optional
    assert(defined(lMatches), "missing HTML tag");
    [_, tag, text] = lMatches;
    hResult = {tag, level: this.level};
    switch (tag) {
      case 'body':
        assert(isEmpty(text), "body tag doesn't allow content");
        break;
      case 'p':
      case 'div':
        if (nonEmpty(text)) {
          hResult.body = text;
        }
        break;
      case 'div:markdown':
        hResult.tag = 'div';
        body = this.fetchBlockAtLevel(level);
        dbg("body", body);
        if (nonEmpty(body)) {
          md = map(import.meta.url, body, SimpleMarkDownMapper);
          dbg("md", md);
          hResult.body = md;
        }
        break;
      default:
        croak(`Unknown tag: ${OL(tag)}`);
    }
    dbgReturn("MyWalker.mapNode", hResult);
    return hResult;
  }

  // .......................................................
  visit(hNode, hUser, lStack) {
    var _, lMatches, lParts, level, result, str, type, uobj;
    dbgEnter('visit', hNode, hUser, lStack);
    ({str, uobj, level, type} = hNode);
    switch (type) {
      case 'comment':
        if (lMatches = str.match(/^\#(.*)$/)) {
          [_, str] = lMatches;
          return indented(`<!-- ${str.trim()} -->`, level);
        } else {
          return undef;
        }
    }
    lParts = [indented(`<${uobj.tag}>`, level)];
    if (nonEmpty(uobj.body)) {
      lParts.push(indented(uobj.body, level + 1));
    }
    result = arrayToBlock(lParts);
    dbgReturn('visit', result);
    return result;
  }

  // .......................................................
  endVisit(hNode, hUser, lStack) {
    var level, type, uobj;
    ({uobj, level, type} = hNode);
    if (type === 'comment') {
      return undef;
    }
    return indented(`</${uobj.tag}>`, level);
  }

};

// ---------------------------------------------------------------------------
(function() {
  var MyTester, treeTester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, HtmlMapper);
    }

  };
  treeTester = new MyTester();
  // ----------------------------------------------------------
  return treeTester.equal(1402, `body
	# a comment

	div:markdown
		A title
		=======

		some text

	div
		p more text`, `<body>
	<div>
		<h1>A title</h1>
		<p>some text</p>
	</div>
	<div>
		<p>
			more text
		</p>
	</div>
</body>`);
})();

// ---------------------------------------------------------------------------
// --- test #ifdef and #ifndef
(function() {
  var MyTester, treeTester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, TreeMapper);
    }

  };
  treeTester = new MyTester();
  return treeTester.equal(1443, `abc
#ifdef something
	def
	ghi
#ifndef something
	xyz`, `abc
xyz`);
})();

// ---------------------------------------------------------------------------
// --- test beginLevel() and endLevel()
(function() {
  var MyTester, MyWalker, lTrace, treeTester;
  lTrace = [];
  MyWalker = class MyWalker extends TreeMapper {
    beginLevel(hUser, level) {
      lTrace.push(`S ${level}`);
    }

    endLevel(hUser, level) {
      lTrace.push(`E ${level}`);
    }

  };
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return map(import.meta.url, block, MyWalker);
    }

  };
  treeTester = new MyTester();
  treeTester.equal(1482, `abc
	def`, `abc
	def`);
  return utest.equal(1490, lTrace, ["S 0", "S 1", "E 1", "E 0"]);
})();
