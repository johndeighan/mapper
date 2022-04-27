// Generated by CoffeeScript 2.7.0
  // TreeMapper.coffee
import {
  undef,
  assert,
  croak,
  deepCopy,
  isString,
  isArray,
  isInteger
} from '@jdeighan/coffee-utils';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  CieloMapper
} from '@jdeighan/mapper/cielomapper';

import {
  TreeWalker
} from '@jdeighan/mapper/walker';

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// --- To derive a class from this:
//        1. Extend this class
//        2. Override mapNode(), which gets the line with
//           any continuation lines appended, plus any
//           HEREDOC sections expanded
//        3. If desired, override handleHereDoc, which patches
//           HEREDOC lines into the original string
export var TreeMapper = class TreeMapper extends CieloMapper {
  constructor(content, source) {
    debug("enter TreeMapper()");
    super(content, source);
    // --- Cached tree, in case getTree() is called multiple times
    this.tree = undef;
    debug("return from TreeMapper()");
  }

  // ..........................................................
  mapString(line, level) {
    var result;
    result = this.mapNode(line, level);
    if (result != null) {
      return [level, this.lineNum, result];
    } else {
      // --- We need to skip over all following nodes
      //     at a higher level than this one
      this.fetchBlock(level + 1);
      return undef;
    }
  }

  // ..........................................................
  mapNode(line, level) {
    return line;
  }

  // ..........................................................
  getAllPairs() {
    var lItems, lPairs, pair;
    // --- This returns a list of pairs, but
    //     we don't need the level anymore since it's
    //     also stored in the node
    debug("enter TreeMapper.getAllPairs()");
    lPairs = super.getAllPairs();
    debug("lPairs", lPairs);
    lItems = (function() {
      var j, len1, results;
      results = [];
      for (j = 0, len1 = lPairs.length; j < len1; j++) {
        pair = lPairs[j];
        results.push(pair[0]);
      }
      return results;
    })();
    debug("return from TreeMapper.getAllPairs()", lItems);
    return lItems;
  }

  // ..........................................................
  getTree() {
    var lItems, tree;
    debug("enter getTree()");
    if (this.tree != null) {
      debug("return cached tree from getTree()");
      return this.tree;
    }
    lItems = this.getAllPairs();
    debug("from getAllPairs()", lItems);
    assert(lItems != null, "lItems is undef");
    assert(isArray(lItems), "getTree(): lItems is not an array");
    // --- treeify will consume its input, so we'll first
    //     make a deep copy
    tree = treeify(deepCopy(lItems));
    debug("TREE", tree);
    this.tree = tree;
    debug("return from getTree()", tree);
    return tree;
  }

  // ..........................................................
  walk() {
    var MyTreeWalker, mapper, tree, walker;
    tree = this.getTree();
    // --- We need this to access our visit() and endVisit()
    //     methods from inside this new class
    mapper = this;
    // --- Create a subclass of TreeWalker that
    //     uses our instances of visit() and endVisit()
    MyTreeWalker = class MyTreeWalker extends TreeWalker {
      visit(node, hInfo, level) {
        return mapper.visit(node, hInfo, level);
      }

      endVisit(node, hInfo, level) {
        return mapper.visit(node, hInfo, level);
      }

      getResult() {
        return mapper.getResult();
      }

    };
    // --- Create an instance of our new class, then walk()
    walker = new MyTreeWalker(tree);
    return walker.walk();
  }

  // ..........................................................
  getResult() {
    return undef;
  }

  // ..........................................................
  visit(node, hInfo, level) {}

  // ..........................................................
  // --- called after all subtrees have been visited
  endVisit(node, hInfo, level) {}

};

// ---------------------------------------------------------------------------
// Utility function to get a tree from text,
//    given a function to map a string (to anything!)
export var treeFromBlock = function(block, mapFunc) {
  var MyTreeMapper, parser;
  MyTreeMapper = class MyTreeMapper extends TreeMapper {
    mapNode(line, level) {
      assert(isString(line), "Mapper.mapNode(): not a string");
      return mapFunc(line, level);
    }

  };
  parser = new MyTreeMapper(block);
  return parser.getTree();
};

// ---------------------------------------------------------------------------
// Each item must be a sub-array with 3 items: [<level>, <lineNum>, <node>]
// If a predicate is supplied, it must return true for any <node>
export var treeify = function(lItems, atLevel = 0, predicate = undef) {
  var err, h, item, lNodes, level, lineNum, node, subtree;
  // --- stop when an item of lower level is found, or at end of array
  debug(`enter treeify(${atLevel})`);
  debug('lItems', lItems);
  try {
    checkTree(lItems, predicate);
    debug("check OK");
  } catch (error) {
    err = error;
    croak(err, 'lItems', lItems);
  }
  lNodes = [];
  while ((lItems.length > 0) && (lItems[0][0] >= atLevel)) {
    item = lItems.shift();
    [level, lineNum, node] = item;
    if (level !== atLevel) {
      croak(`treeify(): item at level ${level}, should be ${atLevel}`, "TREE", lItems);
    }
    h = {node, lineNum};
    subtree = treeify(lItems, atLevel + 1);
    if (subtree != null) {
      h.subtree = subtree;
    }
    lNodes.push(h);
  }
  if (lNodes.length === 0) {
    debug("return undef from treeify()");
    return undef;
  } else {
    debug(`return ${lNodes.length} nodes from treeify()`, lNodes);
    return lNodes;
  }
};

// ---------------------------------------------------------------------------
export var checkTree = function(lItems, predicate) {
  var i, item, j, len, len1, level, lineNum, node;
  // --- Each item should be a sub-array with 3 items:
  //        1. an integer - level
  //        2. an integer - a line number
  //        3. anything, but if predicate is defined, it must return true
  assert(isArray(lItems), "treeify(): lItems is not an array");
  for (i = j = 0, len1 = lItems.length; j < len1; i = ++j) {
    item = lItems[i];
    assert(isArray(item), `treeify(): lItems[${i}] is not an array`);
    len = item.length;
    assert(len === 3, `treeify(): item has length ${len}`);
    [level, lineNum, node] = item;
    assert(isInteger(level), "checkTree(): level not an integer");
    assert(isInteger(lineNum), "checkTree(): lineNum not an integer");
    if (predicate != null) {
      assert(predicate(node), "checkTree(): node fails predicate");
    }
  }
};
