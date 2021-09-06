// Generated by CoffeeScript 2.5.1
  // TreeWalker.coffee
import {
  strict as assert
} from 'assert';

import {
  undef,
  say,
  pass,
  croak,
  isArray,
  isHash,
  isArrayOfHashes
} from '@jdeighan/coffee-utils';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  indented
} from '@jdeighan/coffee-utils/indent';

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
export var TreeWalker = class TreeWalker {
  constructor(root) {
    this.root = root;
    // --- root can be a hash or array of hashes
    pass;
  }

  // ..........................................................
  walk() {
    if (isHash(this.root)) {
      this.walkNode(this.root, 0);
    } else if (isArrayOfHashes(this.root)) {
      this.walkNodes(this.root, 0);
    } else {
      croak("TreeWalker: Invalid root", this.root, 'ROOT');
    }
  }

  // ..........................................................
  walkSubTrees(lSubTrees, level) {
    var i, len, subtree;
    for (i = 0, len = lSubTrees.length; i < len; i++) {
      subtree = lSubTrees[i];
      if (subtree != null) {
        if (isArray(subtree)) {
          this.walkNodes(subtree, level);
        } else if (isHash(subtree)) {
          this.walkNode(subtree, level);
        } else {
          croak("Invalid subtree", subtree, 'SUBTREE');
        }
      }
    }
  }

  // ..........................................................
  walkNode(node, level) {
    var lSubTrees;
    lSubTrees = this.visit(node, level);
    if (lSubTrees) {
      this.walkSubTrees(lSubTrees, level + 1);
    }
    return this.endVisit(node, level);
  }

  // ..........................................................
  walkNodes(lNodes, level = 0) {
    var i, len, node;
    for (i = 0, len = lNodes.length; i < len; i++) {
      node = lNodes[i];
      this.walkNode(node, level);
    }
  }

  // ..........................................................
  // --- return lSubTrees, if any
  visit(node, level) {
    return node.body; // it's handled ok if node.body is undef
  }

  
    // ..........................................................
  // --- called after all subtrees have been visited
  endVisit(node, level) {}

};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
export var ASTWalker = class ASTWalker extends TreeWalker {
  constructor(ast) {
    super(ast.program);
    this.ast = ast.program;
    this.hImports = {};
    this.hMissingSymbols = {};
    // --- subarrays start out as list of formal parameters
    //     to which are added locally assigned variables
    this.lLocalSymbols = [[]];
  }

  // ..........................................................
  isLocalSymbol(name) {
    var i, len, ref, subarray;
    ref = this.lLocalSymbols;
    for (i = 0, len = ref.length; i < len; i++) {
      subarray = ref[i];
      if (subarray.includes(name)) {
        return true;
      }
    }
    return false;
  }

  // ..........................................................
  addImport(name, value = {}) {
    assert(name, "addImport: empty name");
    this.hImports[name] = value;
  }

  // ..........................................................
  addMissingSymbol(name, value = {}) {
    assert(name, "addMissingSymbol: empty name");
    if (!this.isLocalSymbol(name)) {
      this.hMissingSymbols[name] = value;
    }
  }

  // ..........................................................
  addLocalSymbol(name) {
    var lSymbols;
    assert(this.lLocalSymbols.length > 0, "no lLocalSymbols");
    lSymbols = this.lLocalSymbols[this.lLocalSymbols.length - 1];
    lSymbols.push(name);
  }

  // ..........................................................
  visit(node, level) {
    var add, i, lNames, lSubTrees, len, name, param, parm, ref;
    // --- Identifiers that are not local vars or formal params
    //     are symbols that should be imported
    if (node.type === 'Identifier') {
      name = node.name;
      if (!this.isLocalSymbol(name)) {
        this.addMissingSymbol(name);
      }
      return;
    }
    // --- add to local vars & formal params, where appropriate
    switch (node.type) {
      case 'CatchClause':
        param = node.param;
        if ((param != null) && param.type === 'Identifier') {
          this.lLocalSymbols.push(param.name);
        }
        break;
      case 'FunctionExpression':
        lNames = [];
        ref = node.params;
        for (i = 0, len = ref.length; i < len; i++) {
          parm = ref[i];
          if (parm.type === 'Identifier') {
            lNames.push(parm.name);
          }
        }
        this.lLocalSymbols.push(lNames);
        break;
      case 'For':
        lNames = [];
        if ((node.name != null) && (node.name.type === 'Identifier')) {
          lNames.push(node.name.name);
        }
        if ((node.index != null) && (node.name.type === 'Identifier')) {
          lNames.push(node.index.name);
        }
        this.lLocalSymbols.push(lNames);
        break;
      case 'AssignmentExpression':
        if (node.left.type === 'Identifier') {
          this.addLocalSymbol(node.left.name);
        }
        break;
      case 'AssignmentPattern':
        if (node.left.type === 'Identifier') {
          this.addLocalSymbol(node.left.name);
        }
    }
    // --- Build and return array of subtrees
    lSubTrees = [];
    add = function(...subtrees) {
      return lSubTrees.push(...subtrees);
    };
    switch (node.type) {
      case 'AssignmentExpression':
        add(node.left, node.right);
        break;
      case 'AssignmentPattern':
        add(node.left, node.right);
        break;
      case 'BinaryExpression':
        add(node.left, node.right);
        break;
      case 'BlockStatement':
        add(node.body);
        break;
      case 'CallExpression':
        add(node.callee, node.arguments);
        break;
      case 'CatchClause':
        add(node.body);
        break;
      case 'ClassDeclaration':
        add(node.body);
        break;
      case 'ClassBody':
        add(node.body);
        break;
      case 'ClassMethod':
        add(node.body);
        break;
      case 'ExpressionStatement':
        add(node.expression);
        break;
      case 'For':
        add(node.body, node.source);
        break;
      case 'FunctionExpression':
        add(node.params, node.body);
        break;
      case 'IfStatement':
        add(node.test, node.consequent);
        break;
      case 'Program':
        add(node.body);
        break;
      case 'SwitchCase':
        add(node.test, node.consequent);
        break;
      case 'SwitchStatement':
        add(node.cases);
        break;
      case 'TryStatement':
        add(node.block, node.handler, node.finalizer);
        break;
      case 'WhileStatement':
        add(node.test, node.body);
    }
    return lSubTrees;
  }

  // ..........................................................
  endVisit(node, level) {
    // --- Called after the node's entire subtree has been walked
    switch (node.type) {
      case 'FunctionExpression':
      case 'For':
      case 'CatchClause':
        this.lLocalSymbols.pop();
    }
    debug("untree");
  }

  // ..........................................................
  getMissingSymbols() {
    var i, key, len, ref;
    debug("enter CodeWalker.getMissingSymbols()");
    this.hImports = {};
    this.hMissingSymbols = {};
    this.walk();
    ref = Object.keys(this.hImports);
    for (i = 0, len = ref.length; i < len; i++) {
      key = ref[i];
      if (this.hMissingSymbols[key] != null) {
        delete this.hMissingSymbols[key];
      }
    }
    debug("return from CodeWalker.getMissingSymbols()");
    return this.hMissingSymbols;
  }

};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
export var TreeStringifier = class TreeStringifier extends TreeWalker {
  constructor(tree) {
    super(tree); // sets @tree
    this.lLines = [];
  }

  // ..........................................................
  visit(node, level) {
    var str;
    assert(node != null, "TreeStringifier.visit(): empty node");
    debug("enter visit()");
    str = indented(this.stringify(node), level);
    debug(`stringified: '${str}'`);
    this.lLines.push(str);
    if (node.body) {
      debug("return from visit() - has subtree 'body'");
      return node.body;
    } else {
      debug("return from visit()");
      return undef;
    }
  }

  // ..........................................................
  get() {
    this.walk();
    return this.lLines.join('\n');
  }

  // ..........................................................
  excludeKey(key) {
    return key === 'body';
  }

  // ..........................................................
  // --- override this
  stringify(node) {
    var key, newnode, value;
    assert(isHash(node), `TreeStringifier.stringify(): node '${node}' is not a hash`);
    newnode = {};
    for (key in node) {
      value = node[key];
      if (!this.excludeKey(key)) {
        newnode[key] = node[key];
      }
    }
    return JSON.stringify(newnode);
  }

};
