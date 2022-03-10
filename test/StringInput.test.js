// Generated by CoffeeScript 2.6.1
// StringInput.test.coffee
var GatherTester, dir, simple, tester;

import assert from 'assert';

import {
  UnitTester
} from '@jdeighan/unit-tester';

import {
  undef,
  pass,
  isEmpty,
  isComment
} from '@jdeighan/coffee-utils';

import {
  indentLevel,
  undented,
  splitLine,
  indented
} from '@jdeighan/coffee-utils/indent';

import {
  debug,
  debugging,
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  mydir,
  mkpath
} from '@jdeighan/coffee-utils/fs';

import {
  StringInput
} from '@jdeighan/string-input';

dir = mydir(import.meta.url);

process.env.DIR_MARKDOWN = mkpath(dir, 'markdown');

simple = new UnitTester();

/*
	class StringInput should handle the following:
		- #include <file> statements, when DIR_* env vars are set
		- get(), peek(), unget(), skip()
		- overriding of mapLine() to return alternate strings or objects
		- fetch() and fetchBlock() inside mapLine()
*/
// ---------------------------------------------------------------------------
// --- test get(), peek(), unget(), skip()
(function() {
  var input, item, level, pair;
  input = new StringInput(`abc
	def
		ghi`);
  [item, level] = input.peek();
  simple.equal(72, item, 'abc');
  simple.equal(73, level, 0);
  [item, level] = input.peek();
  simple.equal(76, item, 'abc');
  simple.equal(77, level, 0);
  [item, level] = input.get();
  simple.equal(80, item, 'abc');
  simple.equal(81, level, 0);
  [item, level] = input.get();
  simple.equal(84, item, 'def');
  simple.equal(85, level, 1);
  input.unget([item, level]);
  [item, level] = input.get();
  simple.equal(89, item, 'def');
  simple.equal(90, level, 1);
  [item, level] = input.get();
  simple.equal(93, item, 'ghi');
  simple.equal(944, level, 2);
  input.unget(item);
  input.skip();
  pair = input.get();
  return simple.equal(99, pair, undef);
})();

// ---------------------------------------------------------------------------
GatherTester = class GatherTester extends UnitTester {
  transformValue(oInput) {
    assert(oInput instanceof StringInput, "oInput should be a StringInput object");
    return oInput.getAllText();
  }

  normalize(str) {
    return str;
  }

};

tester = new GatherTester();

// ---------------------------------------------------------------------------
// --- Test basic reading till EOF
tester.equal(87, new StringInput(`abc
def`), `abc
def`);

tester.equal(95, new StringInput(`abc

def`), `abc

def`);

(function() {
  var TestInput;
  TestInput = class TestInput extends StringInput {
    mapLine(line, level) {
      if (line === '') {
        return undef;
      } else {
        return line;
      }
    }

  };
  return tester.equal(114, new TestInput(`abc

def`), `abc
def`);
})();

// ---------------------------------------------------------------------------
// --- Test basic use of mapping function
(function() {
  var TestInput;
  TestInput = class TestInput extends StringInput {
    mapLine(line, level) {
      if (line === '') {
        return undef;
      } else {
        return 'x';
      }
    }

  };
  return tester.equal(136, new TestInput(`abc

def`), `x
x`);
})();

// ---------------------------------------------------------------------------
// --- Test ability to access 'this' object from a mapper
//     Goal: remove not only blank lines, but also the line following
(function() {
  var TestInput;
  TestInput = class TestInput extends StringInput {
    mapLine(line, level) {
      var follow;
      if (line === '') {
        follow = this.fetch();
        return undef;
      } else {
        return line;
      }
    }

  };
  return tester.equal(161, new TestInput(`abc

def
ghi`), `abc
ghi`);
})();

// ---------------------------------------------------------------------------
// --- Test continuation lines
(function() {
  var TestInput;
  TestInput = class TestInput extends StringInput {
    mapLine(line, level) {
      var next;
      if (line === '' || isComment(line)) {
        return undef; // skip comments and blank lines
      }
      while ((this.lBuffer.length > 0) && (indentLevel(this.lBuffer[0]) >= level + 2)) {
        next = this.lBuffer.shift();
        line += ' ' + undented(next);
      }
      return line;
    }

  };
  return tester.equal(190, new TestInput(`str = compare(
		"abcde",
		expected
		)

call func
		with multiple
		long parameters

# --- DONE ---`), `str = compare( "abcde", expected )
call func with multiple long parameters`);
})();

// ---------------------------------------------------------------------------
// --- Test overriding the class
(function() {
  var TestInput;
  TestInput = class TestInput extends StringInput {
    mapLine(line, level) {
      if (isEmpty(line)) {
        return undef;
      }
      if (line === 'abc') {
        return '123';
      } else if (line === 'def') {
        return '456';
      } else {
        return line;
      }
    }

  };
  return tester.equal(229, new TestInput(`abc

def`), `123
456`);
})();

// ---------------------------------------------------------------------------
// --- Test #include
tester.equal(243, new StringInput(`abc
	#include title.md
def`), `abc
	title
	=====
def`);

// ---------------------------------------------------------------------------
// --- Test advanced use of mapping function
//        - skip comments and blank lines
//        -
(function() {
  var TestInput;
  TestInput = class TestInput extends StringInput {
    mapLine(line, level) {
      var _, expr, lMatches, varName;
      if (isEmpty(line) || line.match(/^#\s/)) {
        return undef;
      }
      if (lMatches = line.match(/^(?:([A-Za-z][A-Za-z0-9_]*)\s*)?\<\=\=\s*(.*)$/)) { // variable name
        [_, varName, expr] = lMatches;
        return `\`$: ${varName} = ${expr};\``;
      } else {
        return line;
      }
    }

  };
  return tester.equal(280, new TestInput(`abc
myvar    <==     2 * 3

def`), `abc
\`$: myvar = 2 * 3;\`
def`);
})();

// ---------------------------------------------------------------------------
// --- Test #include inside block processed by fetchBlock()
(function() {
  var TestParser, block, line, oInput, text;
  text = `p a paragraph
div:markdown
	#include title.md`;
  block = undef;
  TestParser = class TestParser extends StringInput {
    mapLine(line, level) {
      if (line === 'div:markdown') {
        block = this.fetchBlock(1);
      }
      return line;
    }

  };
  oInput = new TestParser(text);
  [line] = oInput.get();
  simple.equal(312, line, 'p a paragraph');
  [line] = oInput.get();
  simple.equal(314, line, 'div:markdown');
  return simple.equal(315, block, '\ttitle\n\t=====');
})();

// ---------------------------------------------------------------------------
// --- Test blank lines inside a block
(function() {
  var TestParser, block, line, oInput;
  block = undef;
  TestParser = class TestParser extends StringInput {
    mapLine(line, level) {
      if (line === 'div:markdown') {
        block = this.fetchBlock(1);
      }
      return line;
    }

  };
  oInput = new TestParser(`p a paragraph
div:markdown
	line 1

	line 3`);
  [line] = oInput.get();
  simple.equal(339, line, 'p a paragraph');
  [line] = oInput.get();
  simple.equal(341, line, 'div:markdown');
  return simple.equal(342, block, `line 1

line 3`);
})();

// ---------------------------------------------------------------------------
(function() {
  var TestParser, block, line, oInput, text;
  text = `p a paragraph
div:markdown
	#include title.md`;
  block = undef;
  TestParser = class TestParser extends StringInput {
    mapLine(line, level) {
      if (line === 'div:markdown') {
        block = this.fetchBlock(1);
      }
      return line;
    }

  };
  oInput = new TestParser(text);
  [line] = oInput.get();
  simple.equal(368, line, 'p a paragraph');
  [line] = oInput.get();
  simple.equal(371, line, 'div:markdown');
  return simple.equal(373, block, '\ttitle\n\t=====');
})();

// ---------------------------------------------------------------------------
(function() {
  /* Contents of files used:
  	```header.md
  	header
  	======

  		#include para.md
  	```

  	```para.md
  	para
  	----
  	```
   */
  var oInput, text;
  text = `p a paragraph
div:markdown
	#include header.md`;
  oInput = new StringInput(text);
  return tester.equal(401, oInput, `p a paragraph
div:markdown
	header
	======

		para
		----`);
})();

// ---------------------------------------------------------------------------
// --- Test comment
tester.equal(415, new StringInput(`abc

# --- this is a comment

def`), `abc

# --- this is a comment

def`);

// ---------------------------------------------------------------------------
// --- Test using getAll(), i.e. retrieving non-text
(function() {
  var GatherTester2, TestInput2, cmdRE, tester2;
  GatherTester2 = class GatherTester2 extends UnitTester {
    transformValue(oInput) {
      assert(oInput instanceof StringInput, "oInput should be a StringInput object");
      return oInput.getAll();
    }

  };
  tester2 = new GatherTester2();
  cmdRE = /^\s*\#([a-z][a-z_]*)\s*(.*)$/; // skip leading whitespace
  // command name
  // skipwhitespace following command
  // command arguments
  TestInput2 = class TestInput2 extends StringInput {
    mapLine(line, level) {
      var lMatches;
      lMatches = line.match(cmdRE);
      if (lMatches != null) {
        return {
          cmd: lMatches[1],
          argstr: lMatches[2]
        };
      } else {
        return line;
      }
    }

  };
  return tester2.equal(460, new TestInput2(`abc
#if x==y
	def
#else
	ghi`), [
    ['abc',
    0],
    [
      {
        cmd: 'if',
        argstr: 'x==y'
      },
      0
    ],
    ['def',
    1],
    [
      {
        cmd: 'else',
        argstr: ''
      },
      0
    ],
    ['ghi',
    1]
  ]);
})();
