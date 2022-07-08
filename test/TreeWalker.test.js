// Generated by CoffeeScript 2.7.0
// TreeWalker.test.coffee
var HtmlMapper;

import {
  UnitTester,
  UnitTesterNorm,
  simple
} from '@jdeighan/unit-tester';

import {
  assert,
  croak,
  undef,
  pass,
  OL,
  defined,
  isEmpty,
  nonEmpty,
  isString
} from '@jdeighan/coffee-utils';

import {
  indentLevel,
  undented,
  splitLine,
  indented
} from '@jdeighan/coffee-utils/indent';

import {
  debug,
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  mydir,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  arrayToBlock
} from '@jdeighan/coffee-utils/block';

import {
  taml
} from '@jdeighan/coffee-utils/taml';

import {
  doMap
} from '@jdeighan/mapper';

import {
  TreeWalker,
  TraceWalker
} from '@jdeighan/mapper/tree';

import {
  SimpleMarkDownMapper
} from '@jdeighan/mapper/markdown';

import {
  addStdHereDocTypes
} from '@jdeighan/mapper/heredoc';

addStdHereDocTypes();

/*
	class TreeWalker should handle the following:
		- remove empty lines, retain comments
		- extension lines
		- can override @mapStr() - used in @getAll()
		- call @walk() to walk the tree
		- can override beginWalk(), visit(), endVisit(), endWalk()
*/
// ---------------------------------------------------------------------------
// Test TreeWalker.get()
(function() {
  var walker;
  walker = new TreeWalker(undef, `# --- a comment

abc
	def
		ghi`);
  // --- get() should return {uobj, level}
  simple.equal(47, walker.get(), {
    level: 0,
    item: 'abc'
  });
  simple.equal(52, walker.get(), {
    level: 1,
    item: 'def'
  });
  simple.equal(57, walker.get(), {
    level: 2,
    item: 'ghi'
  });
  return simple.equal(62, walker.get(), undef);
})();

// ---------------------------------------------------------------------------
// Test __END__ and extension lines with TreeWalker.get()
(function() {
  var walker;
  walker = new TreeWalker(undef, `abc
		def
	ghi
__END__
		ghi`);
  // --- get() should return {uobj, level}
  simple.equal(79, walker.get(), {
    level: 0,
    item: 'abc def'
  });
  simple.equal(84, walker.get(), {
    level: 1,
    item: 'ghi'
  });
  return simple.equal(89, walker.get(), undef);
})();

// ---------------------------------------------------------------------------
// __END__ only works with no identation
(function() {
  var walker;
  walker = new TreeWalker(undef, `abc
		def
	ghi
	__END__
		ghi`);
  // --- get() should return {uobj, level}
  simple.equal(106, walker.get(), {
    level: 0,
    item: 'abc def'
  });
  simple.equal(111, walker.get(), {
    level: 1,
    item: 'ghi'
  });
  simple.equal(116, walker.get(), {
    level: 1,
    item: '__END__'
  });
  simple.equal(121, walker.get(), {
    level: 2,
    item: 'ghi'
  });
  return simple.equal(126, walker.get(), undef);
})();

// ---------------------------------------------------------------------------
(function() {
  var Tester, tester;
  Tester = class Tester extends UnitTester {
    transformValue(block) {
      return doMap(TreeWalker, import.meta.url, block);
    }

  };
  tester = new Tester();
  // ---------------------------------------------------------------------------
  // --- Test basic reading till EOF
  tester.equal(144, `abc
def`, `abc
def`);
  return tester.equal(152, `abc

def`, `abc
def`);
})();

// ---------------------------------------------------------------------------
// Test empty line handling
(function() {
  var MyTester, MyWalker, block, tester;
  MyWalker = class MyWalker extends TreeWalker {
    // --- This removes blank lines
    handleEmptyLine() {
      debug("in MyWalker.handleEmptyLine()");
      return undef;
    }

  };
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(MyWalker, import.meta.url, block);
    }

  };
  tester = new MyTester();
  // ..........................................................
  block = `abc

def`;
  simple.equal(192, doMap(MyWalker, import.meta.url, block), `abc
def`);
  return tester.equal(197, block, `abc
def`);
})();

// ---------------------------------------------------------------------------
// Test comment handling
(function() {
  var MyTester, MyWalker, block, tester;
  MyWalker = class MyWalker extends TreeWalker {
    isComment(line) {
      // --- comments start with //
      return line.match(/^\s*\/\//);
    }

    handleComment(line) {
      // --- remove comments
      return undef;
    }

  };
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(MyWalker, import.meta.url, block);
    }

  };
  tester = new MyTester();
  // ..........................................................
  block = `// a comment - should be removed
//also a comment
# not a comment
abc
def`;
  simple.equal(240, doMap(MyWalker, import.meta.url, block), `# not a comment
abc
def`);
  return tester.equal(246, block, `# not a comment
abc
def`);
})();

// ---------------------------------------------------------------------------
// Test command handling
(function() {
  var MyTester, MyWalker, block, tester;
  MyWalker = class MyWalker extends TreeWalker {
    isCmd(line) {
      var _, cmd, lMatches;
      // --- line includes any indentation

      // --- commands only recognized if no indentation
      //     AND consist of '-' + one whitespace char + word
      if ((lMatches = line.match(/^-\s(\w+)$/))) {
        [_, cmd] = lMatches;
        return {
          cmd,
          argstr: '',
          prefix: ''
        };
      } else {
        return undef;
      }
    }

    // .......................................................
    handleCmd(cmd, argstr, prefix) {
      return `COMMAND: ${cmd}`;
    }

  };
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(MyWalker, import.meta.url, block);
    }

  };
  tester = new MyTester();
  // ..........................................................
  block = `# remove this

abc
- command
def`;
  return tester.equal(300, block, `abc
COMMAND: command
def`);
})();

// ---------------------------------------------------------------------------
// try retaining indentation for mapped lines
(function() {
  var MyTester, MyWalker, tester;
  // --- NOTE: If you don't override unmapObj(), then
  //           mapStr() must return {str: <string>, level: <level>}
  //           or undef to ignore the line
  MyWalker = class MyWalker extends TreeWalker {
    // --- This maps all non-empty lines to the string 'x'
    //     and removes all empty lines
    mapStr(str, level) {
      debug(`enter mapStr('${str}', ${level}`);
      if (isEmpty(str)) {
        debug("return undef from mapStr() - empty line");
        return undef;
      } else {
        debug("return 'x' from mapStr()");
        return 'x';
      }
    }

  };
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(MyWalker, import.meta.url, block);
    }

  };
  tester = new MyTester();
  // ..........................................................
  return tester.equal(343, `abc
	def

ghi`, `x
	x
x`);
})();

// ---------------------------------------------------------------------------
// --- Test ability to access 'this' object from a walker
//     Goal: remove not only blank lines, but also the line following
(function() {
  var MyTester, MyWalker, tester;
  MyWalker = class MyWalker extends TreeWalker {
    // --- Remove blank lines PLUS the line following a blank line
    handleEmptyLine(line) {
      var follow;
      follow = this.fetch();
      return undef; // remove empty lines
    }

  };
  
    // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(MyWalker, import.meta.url, block);
    }

  };
  tester = new MyTester();
  // ..........................................................
  return tester.equal(381, `abc

def
ghi`, `abc
ghi`);
})();

// ---------------------------------------------------------------------------
// --- Test #include
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(TreeWalker, import.meta.url, block);
    }

  };
  // ..........................................................
  tester = new MyTester();
  return tester.equal(407, `abc
	#include title.md
def`, `abc
	title
	=====
def`);
})();

// ---------------------------------------------------------------------------
// --- Test getAll()
(function() {
  var MyTester, tester;
  // ..........................................................
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      var walker;
      walker = new TreeWalker(undef, block);
      return walker.getAll();
    }

  };
  tester = new MyTester();
  return tester.equal(436, `abc
	def
		ghi
jkl`, taml(`---
-
	level: 0
	item: 'abc'
-
	level: 1
	item: 'def'
-
	level: 2
	item: 'ghi'
-
	level: 0
	item: 'jkl'`));
})();

// ---------------------------------------------------------------------------
(function() {
  var walker;
  walker = new TreeWalker(undef, `if (x == 2)
	doThis
	doThat
		then this
while (x > 2)
	--x`);
  simple.equal(476, walker.peek(), {
    level: 0,
    item: 'if (x == 2)'
  });
  simple.equal(477, walker.get(), {
    level: 0,
    item: 'if (x == 2)'
  });
  simple.equal(479, walker.peek(), {
    level: 1,
    item: 'doThis'
  });
  simple.equal(480, walker.get(), {
    level: 1,
    item: 'doThis'
  });
  simple.equal(482, walker.peek(), {
    level: 1,
    item: 'doThat'
  });
  simple.equal(483, walker.get(), {
    level: 1,
    item: 'doThat'
  });
  simple.equal(485, walker.peek(), {
    level: 2,
    item: 'then this'
  });
  simple.equal(486, walker.get(), {
    level: 2,
    item: 'then this'
  });
  simple.equal(488, walker.peek(), {
    level: 0,
    item: 'while (x > 2)'
  });
  simple.equal(489, walker.get(), {
    level: 0,
    item: 'while (x > 2)'
  });
  simple.equal(491, walker.peek(), {
    level: 1,
    item: '--x'
  });
  return simple.equal(492, walker.get(), {
    level: 1,
    item: '--x'
  });
})();

// ---------------------------------------------------------------------------
// --- Test fetchBlockAtLevel()
(function() {
  var walker;
  walker = new TreeWalker(undef, `if (x == 2)
	doThis
	doThat
		then this
while (x > 2)
	--x`);
  simple.equal(510, walker.get(), {
    level: 0,
    item: 'if (x == 2)'
  });
  simple.equal(516, walker.fetchBlockAtLevel(1), `doThis
doThat
	then this`);
  simple.equal(522, walker.get(), {
    level: 0,
    item: 'while (x > 2)'
  });
  return simple.equal(528, walker.fetchBlockAtLevel(1), "--x");
})();

// ---------------------------------------------------------------------------
// --- Test fetchBlockAtLevel() with mapping
(function() {
  var MyWalker, walker;
  MyWalker = class MyWalker extends TreeWalker {
    mapStr(str, level) {
      var _, cmd, cond, lMatches;
      if ((lMatches = str.match(/^(if|while)\s*(.*)$/))) {
        [_, cmd, cond] = lMatches;
        return {cmd, cond};
      } else {
        return str;
      }
    }

  };
  walker = new MyWalker(undef, `if (x == 2)
	doThis
	doThat
		then this
while (x > 2)
	--x`);
  simple.equal(558, walker.get(), {
    level: 0,
    item: {
      cmd: 'if',
      cond: '(x == 2)'
    }
  });
  simple.equal(566, walker.fetchBlockAtLevel(1), `doThis
doThat
	then this`);
  simple.equal(571, walker.get(), {
    level: 0,
    item: {
      cmd: 'while',
      cond: '(x > 2)'
    }
  });
  simple.equal(579, walker.fetchBlockAtLevel(1), "--x");
  return simple.equal(580, walker.get(), undef);
})();

// ---------------------------------------------------------------------------
// --- Test TraceWalker
(function() {
  var WalkTester, tester;
  WalkTester = class WalkTester extends UnitTester {
    transformValue(block) {
      var walker;
      walker = new TraceWalker(import.meta.url, block);
      return walker.walk();
    }

  };
  tester = new WalkTester();
  // ..........................................................
  tester.equal(599, `abc
def`, `BEGIN WALK
VISIT 0 'abc'
END VISIT 0 'abc'
VISIT 0 'def'
END VISIT 0 'def'
END WALK`);
  tester.equal(611, `abc
	def`, `BEGIN WALK
VISIT 0 'abc'
VISIT 1 'def'
END VISIT 1 'def'
END VISIT 0 'abc'
END WALK`);
  // --- 2 indents is treated as an extension line
  tester.equal(624, `abc
		def`, `BEGIN WALK
VISIT 0 'abc˳def'
END VISIT 0 'abc˳def'
END WALK`);
  return tester.equal(634, `abc
	def
ghi`, `BEGIN WALK
VISIT 0 'abc'
VISIT 1 'def'
END VISIT 1 'def'
END VISIT 0 'abc'
VISIT 0 'ghi'
END VISIT 0 'ghi'
END WALK`);
})();

// ---------------------------------------------------------------------------
// --- Test HEREDOC
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(TreeWalker, import.meta.url, block);
    }

  };
  // ..........................................................
  tester = new MyTester();
  tester.equal(665, `abc
if x == <<<
	abc
	def

def`, `abc
if x == "abc\\ndef"
def`);
  tester.equal(678, `abc
if x == <<<
	===
	abc
	def

def`, `abc
if x == "abc\\ndef"
def`);
  return tester.equal(692, `abc
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
HtmlMapper = class HtmlMapper extends TreeWalker {
  mapStr(str, level) {
    var _, body, hResult, lMatches, md, tag, text;
    debug(`enter MyWalker.mapStr(${level})`, str);
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
        body = this.fetchBlockAtLevel(level + 1);
        debug("body", body);
        if (nonEmpty(body)) {
          md = doMap(SimpleMarkDownMapper, import.meta.url, body);
          debug("md", md);
          hResult.body = md;
        }
        break;
      default:
        croak(`Unknown tag: ${OL(tag)}`);
    }
    debug("return from MyWalker.mapStr()", hResult);
    return hResult;
  }

  // .......................................................
  visit(uobj, hUser, level) {
    var lParts, result;
    lParts = [indented(`<${uobj.tag}>`, level)];
    if (nonEmpty(uobj.body)) {
      lParts.push(indented(uobj.body, level + 1));
    }
    result = arrayToBlock(lParts);
    debug('result', result);
    return result;
  }

  // .......................................................
  endVisit(uobj, hUser, level) {
    return indented(`</${uobj.tag}>`, level);
  }

};

// ---------------------------------------------------------------------------
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(HtmlMapper, import.meta.url, block);
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  return tester.equal(777, `body
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

// --- TO DO: Add tests to show that comments/blank lines can be retained

  // ---------------------------------------------------------------------------
// --- test #ifdef and #ifndef
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      return doMap(TreeWalker, import.meta.url, block);
    }

  };
  tester = new MyTester();
  return tester.equal(820, `abc
#ifdef something
	def
	ghi
#ifndef something
	xyz`, `abc
xyz`);
})();
