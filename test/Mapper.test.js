// Generated by CoffeeScript 2.7.0
// Mapper.test.coffee
var JSMapper;

import {
  undef,
  defined,
  notdefined,
  rtrim,
  toBlock
} from '@jdeighan/base-utils';

import {
  assert,
  croak
} from '@jdeighan/base-utils/exceptions';

import {
  LOG,
  LOGVALUE
} from '@jdeighan/base-utils/log';

import {
  dbg,
  dbgEnter,
  dbgReturn,
  setDebugging
} from '@jdeighan/base-utils/debug';

import {
  UnitTester,
  utest
} from '@jdeighan/unit-tester';

import {
  indented
} from '@jdeighan/coffee-utils/indent';

import {
  Mapper,
  map
} from '@jdeighan/mapper';

// ---------------------------------------------------------------------------
// --- Special lines
(function() {
  var mapper;
  mapper = new Mapper(`line1
# a comment
line2

line3`);
  utest.like(27, mapper.get(), {
    str: 'line1',
    level: 0,
    source: "<unknown>/1"
  });
  utest.like(32, mapper.get(), {
    str: 'line2',
    level: 0,
    source: "<unknown>/3"
  });
  utest.like(37, mapper.get(), {
    str: 'line3',
    level: 0,
    source: "<unknown>/5"
  });
  return utest.equal(42, mapper.get(), undef);
})();

// ---------------------------------------------------------------------------
// --- Test allNodes()
(function() {
  var item, lStrings, mapper, ref;
  mapper = new Mapper(`abc
def
ghi`);
  lStrings = [];
  ref = mapper.allNodes();
  // --- By default, the end line is kept
  for (item of ref) {
    lStrings.push(item.str);
  }
  return utest.equal(66, lStrings, ['abc', 'def', 'ghi']);
})();

// ---------------------------------------------------------------------------
(function() {
  var item, lStrings, mapper, ref;
  mapper = new Mapper(`abc
def
ghi`);
  lStrings = [];
  ref = mapper.allNodes();
  for (item of ref) {
    lStrings.push(item.str);
  }
  return utest.equal(89, lStrings, ['abc', 'def', 'ghi']);
})();

// ---------------------------------------------------------------------------
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var block, mapper;
      mapper = new Mapper(hInput);
      block = mapper.getBlock();
      return block;
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  return tester.equal(110, `abc

def
# --- a comment`, `abc
def`);
})();

// ---------------------------------------------------------------------------
// --- to prevent mapping, you must use fetch()
(function() {
  var MyTester, tester;
  MyTester = class MyTester extends UnitTester {
    transformValue(hInput) {
      var hNode, lLines, mapper;
      mapper = new Mapper(hInput);
      lLines = [];
      while (defined(hNode = mapper.fetch())) {
        if (hNode.str === 'stop') {
          break;
        }
        lLines.push(hNode.str);
      }
      return toBlock(lLines);
    }

  };
  tester = new MyTester();
  // ----------------------------------------------------------
  return tester.equal(145, `abc

def
# --- a comment
stop
ghi`, `abc

def
# --- a comment`);
})();

// ---------------------------------------------------------------------------
(function() {
  var generator, mapper;
  // --- A generator is a function that, when you call it,
  //     it returns an iterator
  generator = function*() {
    yield 'line1';
    yield 'line2';
    yield 'line3';
  };
  // --- You can pass any iterator to the Mapper() constructor
  mapper = new Mapper(generator());
  utest.like(177, mapper.fetch(), {
    str: 'line1'
  });
  utest.like(178, mapper.fetch(), {
    str: 'line2'
  });
  utest.like(179, mapper.fetch(), {
    str: 'line3'
  });
  return utest.equal(180, mapper.fetch(), undef);
})();

// ---------------------------------------------------------------------------
// File title.md contains:
// title
// =====
// ---------------------------------------------------------------------------
// --- Test #include
(function() {
  var MyTester, myTester, numLines;
  numLines = undef;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      var mapper;
      mapper = new Mapper(block);
      block = mapper.getBlock();
      numLines = mapper.lineNum; // set variable numLines
      return block;
    }

  };
  // ..........................................................
  myTester = new MyTester();
  myTester.equal(207, `abc
	#include title.md
def`, `abc
	title
	=====
def`);
  return utest.equal(218, numLines, 3);
})();

// ---------------------------------------------------------------------------
(function() {
  var mapper;
  mapper = new Mapper(`abc
	#include title.md
def`);
  return utest.equal(231, mapper.getBlock(), `abc
	title
	=====
def`);
})();

// ---------------------------------------------------------------------------
// --- Test __END__
(function() {
  var MyTester, myTester, numLines;
  numLines = undef;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      var mapper;
      mapper = new Mapper(block);
      block = mapper.getBlock();
      numLines = mapper.lineNum; // set variable numLines
      return block;
    }

  };
  // ..........................................................
  myTester = new MyTester();
  myTester.equal(259, `abc
def
__END__
ghi
jkl`, `abc
def`);
  return utest.equal(270, numLines, 2);
})();

// ---------------------------------------------------------------------------
// --- Test #include with __END__
(function() {
  var MyTester, myTester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      var mapper;
      mapper = new Mapper(block);
      block = mapper.getBlock();
      return block;
    }

  };
  // ..........................................................
  myTester = new MyTester();
  return myTester.equal(290, `abc
	#include ended.md
def`, `abc
	ghi
def`);
})();

// ---------------------------------------------------------------------------
// --- Test #define
(function() {
  var MyTester, myTester;
  MyTester = class MyTester extends UnitTester {
    transformValue(block) {
      var mapper;
      mapper = new Mapper(block);
      block = mapper.getBlock();
      return block;
    }

  };
  // ..........................................................
  myTester = new MyTester();
  return myTester.equal(319, `abc
#define meaning 42
meaning is __meaning__`, `abc
meaning is 42`);
})();

// ---------------------------------------------------------------------------
// --- Test map()
(function() {
  var MyMapper, result;
  // --- Usually:
  //        1. empty lines are removed
  //        2. '#' style comments are recognized and removed
  //        3. Only the #define command is interpreted
  result = map(`# - test.txt

abc
#define meaning 42
The meaning of life is __meaning__`);
  utest.equal(348, result, `abc
The meaning of life is 42`);
  // --- Now, create a subclass that:
  //        1. recognizes '//' style comments and removes them
  //        2. implements a '#for <args>' cmd that outputs '{#for <args>}'
  MyMapper = class MyMapper extends Mapper {
    isComment(hNode) {
      return hNode.str.match(/^\s*\/\//);
    }

    mapCmd(hNode) {
      var argstr, cmd;
      ({cmd, argstr} = hNode.uobj);
      if (cmd === 'for') {
        return indented(`{#for ${argstr}}`, hNode.level, this.oneIndent);
      } else {
        return super.mapCmd(hNode);
      }
    }

  };
  result = map(`// test.txt

abc
#define meaning 42
The meaning of life is __meaning__
#for x in lItems`, MyMapper);
  return utest.equal(377, result, `abc
The meaning of life is 42
{#for x in lItems}`);
})();

// ---------------------------------------------------------------------------
// --- Test mapToUserObj
(function() {
  var MyMapper, result;
  MyMapper = class MyMapper extends Mapper {
    // --- change definition of a comment
    isComment(hNode) {
      return hNode.str.match(/\s*\/\//);
    }

    mapEmptyLine(hNode) {
      return undef;
    }

    mapComment(hNode) {
      return undef;
    }

    mapToUserObj(hNode) {
      return hNode.str.length.toString();
    }

  };
  result = map(`// test.txt

abc

defghi`, MyMapper);
  return utest.equal(406, result, `3
6`);
})();

// ---------------------------------------------------------------------------
// --- Test complex mapping,
//     where source is passed through multiple mappers

  // ---------------------------------------------------------------------------
// JSMapper:
//    1. retains comments
//    2. removes empty lines
//    3. appends a semicolon to each non-comment line
JSMapper = class JSMapper extends Mapper {
  mapComment(hNode) {
    return hNode.str;
  }

  mapToUserObj(hNode) {
    return hNode.str + ';';
  }

};

(function() {
  var JSTester, mapTester;
  JSTester = class JSTester extends UnitTester {
    transformValue(block) {
      return map(block, JSMapper);
    }

  };
  mapTester = new JSTester();
  // --- some utest tests of JSMapper
  mapTester.equal(444, `# |||| $:
y = 2*x`, `# |||| $:
y = 2*x;`);
  return mapTester.equal(452, `# |||| $: {
y = 2*x
console.log "OK"
# |||| }`, `# |||| $: {
y = 2*x;
console.log "OK";
# |||| }`);
})();

// ---------------------------------------------------------------------------
// BarMapper should:
//    1. Remove comments and empty lines   (happens by default)
//    2. Convert
//          #reactive <code>
//       to
//          # |||| $:
//          <code>
//    3. Convert
//          #reactive
//             <code>
//       to
//          # |||| $: {
//          <code>
//          # |||| }
export var BarMapper = class BarMapper extends Mapper {
  mapCmd(hNode) {
    var argstr, block, cmd, code, lLines, level, str, uobj;
    dbgEnter("mapCmd", hNode);
    ({str, uobj, level} = hNode);
    ({cmd, argstr} = uobj); // isCmd() put this here
    if (cmd === 'reactive') {
      if (argstr === '') {
        // --- A reactive block
        lLines = this.fetchLinesAtLevel(level + 1);
        // --- simulate conversion to JavaScript
        code = map(lLines, JSMapper);
        block = toBlock(["# |||| $: {", code, "# |||| }"]);
      } else {
        // --- A reactive statement
        code = map(argstr, JSMapper);
        block = toBlock(["# |||| $:", code]);
      }
      dbgReturn("mapCmd", block);
      return block;
    }
    return super.mapCmd(hNode);
  }

};

(function() {
  var BarTester, mapTester;
  BarTester = class BarTester extends UnitTester {
    transformValue(block) {
      return map(block, BarMapper);
    }

  };
  mapTester = new BarTester();
  // ..........................................................
  // --- some utest tests of BarMapper
  mapTester.equal(530, `# --- a comment (should remove)

<h1>title</h1>
<script>
	#reactive y = 2*x
</script>`, `<h1>title</h1>
<script>
	# |||| $:
	y = 2*x;
</script>`);
  return mapTester.equal(545, `# --- a comment (should remove)

<h1>title</h1>
<script>
	#reactive
		y = 2*x
		console.log "OK"
</script>`, `<h1>title</h1>
<script>
	# |||| $: {
	y = 2*x;
	console.log "OK";
	# |||| }
</script>`);
})();

// ---------------------------------------------------------------------------
// DebarMapper should convert:
//     # |||| <something>
// to
//     <something>
export var DebarMapper = class DebarMapper extends Mapper {
  mapComment(hNode) {
    var _commentText, lMatches, level, str, uobj;
    ({str, uobj, level, _commentText} = hNode);
    if (lMatches = _commentText.match(/^\|\|\|\|\s*(.*)$/)) { // 4 vertical bars
      // skip whitespace
      // anything
      str = lMatches[1];
    }
    return str;
  }

};

(function() {
  var DebarTester, mapTester;
  DebarTester = class DebarTester extends UnitTester {
    transformValue(block) {
      return map(block, DebarMapper);
    }

  };
  mapTester = new DebarTester();
  // ..........................................................
  // --- some utest tests of DebarMapper
  mapTester.equal(600, `<h1>title</h1>
<script>
	# |||| $:
	y = 2*x
</script>`, `<h1>title</h1>
<script>
	$:
	y = 2*x
</script>`);
  return mapTester.equal(614, `<h1>title</h1>
<script>
	# |||| $: {
	y = 2*x
	console.log "OK"
	# |||| }
</script>`, `<h1>title</h1>
<script>
	$: {
	y = 2*x
	console.log "OK"
	}
</script>`);
})();

// ---------------------------------------------------------------------------
(function() {
  var MultiTester, mapTester;
  MultiTester = class MultiTester extends UnitTester {
    transformValue(block) {
      return map(block, [BarMapper, DebarMapper]);
    }

  };
  mapTester = new MultiTester();
  // ..........................................................
  // --- some utest tests of multiple mapping
  mapTester.equal(649, `# --- a comment (should remove)

<h1>title</h1>
<script>
	#reactive y = 2*x
</script>`, `<h1>title</h1>
<script>
	$:
	y = 2*x;
</script>`);
  return mapTester.equal(664, `# --- a comment (should remove)

<h1>title</h1>
<script>
	#reactive
		y = 2*x
		console.log "OK"
</script>`, `<h1>title</h1>
<script>
	$: {
	y = 2*x;
	console.log "OK";
	}
</script>`);
})();
