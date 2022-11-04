// Generated by CoffeeScript 2.7.0
// ASTWalker.coffee
var hAllHandlers;

import {
  assert,
  croak,
  LOG,
  LOGVALUE
} from '@jdeighan/exceptions';

import {
  dbg,
  dbgEnter,
  dbgReturn
} from '@jdeighan/exceptions/debug';

import {
  fromTAML,
  toTAML
} from '@jdeighan/exceptions/taml';

import {
  undef,
  pass,
  defined,
  notdefined,
  OL,
  words,
  deepCopy,
  getOptions,
  isString,
  nonEmpty,
  isArray,
  isHash,
  isArrayOfHashes,
  removeKeys
} from '@jdeighan/coffee-utils';

import {
  indented
} from '@jdeighan/coffee-utils/indent';

import {
  toBlock
} from '@jdeighan/coffee-utils/block';

import {
  barf
} from '@jdeighan/coffee-utils/fs';

import {
  coffeeCodeToAST
} from '@jdeighan/mapper/coffee';

import {
  Context
} from '@jdeighan/mapper/context';

hAllHandlers = fromTAML(`---
File:
	lWalkTrees:
		- program
Program:
	lWalkTrees:
		- body
ArrayExpression:
	lWalkTrees:
		- elements
AssignmentExpression:
	lDefined:
		- left
	lUsed:
		- right
AssignmentPattern:
	lDefined:
		- left
	lWalkTrees:
		- right
BinaryExpression:
	lUsed:
		- left
		- right
BlockStatement:
	lWalkTrees:
		- body
ClassBody:
	lWalkTrees:
		- body
ClassDeclaration:
	lWalkTrees:
		- body
ClassMethod:
	lWalkTrees:
		- body
ExpressionStatement:
	lWalkTrees:
		- expression
IfStatement:
	lWalkTrees:
		- test
		- consequent
		- alternate
LogicalExpression:
	lWalkTrees:
		- left
		- right
SpreadElement:
	lWalkTrees:
		- argument
SwitchStatement:
	lWalkTrees:
		- cases
SwitchCase:
	lWalkTrees:
		- test
		- consequent
TemplateLiteral:
	lWalkTrees:
		- expressions
TryStatement:
	lWalkTrees:
		- block
		- handler
		- finalizer
WhileStatement:
	lWalkTrees:
		- test
		- body`);

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
export var ASTWalker = class ASTWalker {
  constructor(from) {
    dbgEnter("ASTWalker", from);
    if (isString(from)) {
      this.ast = coffeeCodeToAST(from);
    } else {
      this.ast = from;
    }
    // --- @ast can be a hash or array of hashes
    if (isHash(this.ast)) {
      dbg("tree was hash - constructing list from it");
      this.ast = [this.ast];
    }
    assert(isArrayOfHashes(this.ast), `not array of hashes: ${OL(this.ast)}`);
    // --- Info to accumulate
    this.lImportedSymbols = [];
    this.lExportedSymbols = [];
    this.lUsedSymbols = [];
    this.lMissingSymbols = [];
    this.context = new Context();
    dbgReturn("ASTWalker");
  }

  // ..........................................................
  addImport(name, lib) {
    dbgEnter("addImport", name, lib);
    this.check(name);
    if (this.lImportedSymbols.includes(name)) {
      LOG(`Duplicate import: ${name}`);
    } else {
      this.lImportedSymbols.push(name);
    }
    this.context.addGlobal(name);
    dbgReturn("addImport");
  }

  // ..........................................................
  addExport(name, lib) {
    dbgEnter("addExport", name);
    this.check(name);
    if (this.lExportedSymbols.includes(name)) {
      LOG(`Duplicate export: ${name}`);
    } else {
      this.lExportedSymbols.push(name);
    }
    dbgReturn("addExport");
  }

  // ..........................................................
  addDefined(name, value = {}) {
    dbgEnter("addDefined", name);
    this.check(name);
    if (this.context.atGlobalLevel()) {
      this.context.addGlobal(name);
    } else {
      this.context.add(name);
    }
    dbgReturn("addDefined");
  }

  // ..........................................................
  addUsed(name, value = {}) {
    dbgEnter("addUsed", name);
    this.check(name);
    if (!this.lUsedSymbols.includes(name)) {
      this.lUsedSymbols.push(name);
    }
    if (!this.context.has(name) && !this.lMissingSymbols.includes(name)) {
      this.lMissingSymbols.push(name);
    }
    dbgReturn("addUsed");
  }

  // ..........................................................
  walk(options = undef) {
    var asText, hInfo, i, j, k, lLines, lNotNeeded, label, len, len1, len2, name, node, ref, ref1, ref2, result;
    // --- Valid options:
    //        asText
    dbgEnter("walk");
    ref = this.ast;
    for (i = 0, len = ref.length; i < len; i++) {
      node = ref[i];
      this.visit(node, 0);
    }
    // --- get symbols to return

    // --- not needed if:
    //        1. in lImported
    //        2. not in lUsedSymbols
    //        3. not in lExportedSymbols
    lNotNeeded = [];
    ref1 = this.lImportedSymbols;
    for (j = 0, len1 = ref1.length; j < len1; j++) {
      name = ref1[j];
      if (!this.lUsedSymbols.includes(name) && !this.lExportedSymbols.includes(name)) {
        lNotNeeded.push(name);
      }
    }
    hInfo = {
      lImported: this.lImportedSymbols,
      lExported: this.lExportedSymbols,
      lUsed: this.lUsedSymbols,
      lMissing: this.lMissingSymbols,
      lNotNeeded
    };
    ({asText} = getOptions(options));
    if (asText) {
      lLines = [];
      ref2 = words('lImported lExported lMissing');
      for (k = 0, len2 = ref2.length; k < len2; k++) {
        label = ref2[k];
        if (nonEmpty(hInfo[label])) {
          lLines.push(`${label}: ${hInfo[label].join(' ')}`);
        }
      }
      result = toBlock(lLines);
    } else {
      result = hInfo;
    }
    dbgReturn("walk", result);
    return result;
  }

  // ..........................................................
  walkTree(tree, level = 0) {
    var i, len, node;
    dbgEnter("walkTree");
    if (isArray(tree)) {
      for (i = 0, len = tree.length; i < len; i++) {
        node = tree[i];
        this.walkTree(node, level);
      }
    } else {
      assert(isHash(tree, ['type']), `bad tree: ${OL(tree)}`);
      this.visit(tree, level);
    }
    dbgReturn("walkTree");
  }

  // ..........................................................
  // --- return true if handled, false if not
  handle(node, level) {
    var hHandlers, i, j, k, key, l, lDefined, lUsed, lWalkTrees, len, len1, len2, len3, subnode, tree, type;
    dbgEnter("handle");
    ({type} = node);
    dbg(`type is ${OL(type)}`);
    hHandlers = hAllHandlers[type];
    if (notdefined(hHandlers)) {
      dbgReturn("handle", false);
      return false;
    }
    ({lWalkTrees, lDefined, lUsed} = hHandlers);
    if (defined(lDefined)) {
      dbg("has lDefined");
      for (i = 0, len = lDefined.length; i < len; i++) {
        key = lDefined[i];
        subnode = node[key];
        if (subnode.type === 'Identifier') {
          this.addDefined(subnode.name);
        } else {
          this.walkTree(subnode, level + 1);
        }
      }
    }
    if (defined(lUsed)) {
      dbg("has lUsed");
      for (j = 0, len1 = lUsed.length; j < len1; j++) {
        key = lUsed[j];
        subnode = node[key];
        if (subnode.type === 'Identifier') {
          this.addUsed(subnode.name);
        } else {
          this.walkTree(subnode, level + 1);
        }
      }
    }
    if (defined(lWalkTrees)) {
      dbg("has lWalkTrees");
      for (k = 0, len2 = lWalkTrees.length; k < len2; k++) {
        key = lWalkTrees[k];
        subnode = node[key];
        if (isArray(subnode)) {
          for (l = 0, len3 = subnode.length; l < len3; l++) {
            tree = subnode[l];
            this.walkTree(tree, level + 1);
          }
        } else if (defined(subnode)) {
          this.walkTree(subnode, level + 1);
        }
      }
    }
    dbgReturn("handle", true);
    return true;
  }

  // ..........................................................
  visit(node, level) {
    var arg, argument, body, callee, declaration, hSpec, i, id, importKind, imported, j, k, l, lParmNames, left, len, len1, len2, len3, len4, lib, local, m, name, object, param, parm, ref, ref1, ref2, right, source, spec, specifiers, type;
    dbgEnter("ASTWalker.visit", node, level);
    assert(defined(node), "node is undef");
    if (this.handle(node, level)) {
      dbgReturn("ASTWalker.visit");
      return;
    }
    switch (node.type) {
      case 'CallExpression':
        ({callee} = node);
        if (callee.type === 'Identifier') {
          this.addUsed(callee.name);
        } else {
          this.walkTree(callee, level + 1);
        }
        ref = node.arguments;
        for (i = 0, len = ref.length; i < len; i++) {
          arg = ref[i];
          if (arg.type === 'Identifier') {
            this.addUsed(arg.name);
          } else {
            this.walkTree(arg, level + 1);
          }
        }
        break;
      case 'CatchClause':
        param = node.param;
        if (defined(param) && (param.type === 'Identifier')) {
          this.addDefined(param.name);
        }
        this.walkTree(node.body, level + 1);
        break;
      case 'ExportNamedDeclaration':
        //				console.dir node
        ({specifiers, declaration} = node);
        if (defined(declaration)) {
          ({type, id, left, body} = declaration);
          switch (type) {
            case 'ClassDeclaration':
              if (defined(id)) {
                this.addExport(id.name);
              } else if (defined(body)) {
                this.walkTree(node.body, level + 1);
              }
              break;
            case 'AssignmentExpression':
              if (left.type === 'Identifier') {
                this.addExport(left.name);
              }
          }
          this.walkTree(declaration, level + 1);
        }
        if (defined(specifiers)) {
          for (j = 0, len1 = specifiers.length; j < len1; j++) {
            spec = specifiers[j];
            name = spec.exported.name;
            this.addExport(name);
          }
        }
        break;
      case 'For':
        if (defined(node.name) && (node.name.type === 'Identifier')) {
          this.addDefined(node.name.name);
        }
        if (defined(node.index) && (node.name.type === 'Identifier')) {
          this.addDefined(node.index.name);
        }
        this.walkTree(node.source, level + 1);
        this.walkTree(node.body, level + 1);
        break;
      case 'FunctionExpression':
      case 'ArrowFunctionExpression':
        lParmNames = [];
        if (defined(node.params)) {
          ref1 = node.params;
          for (k = 0, len2 = ref1.length; k < len2; k++) {
            parm = ref1[k];
            switch (parm.type) {
              case 'Identifier':
                lParmNames.push(parm.name);
                break;
              case 'AssignmentPattern':
                ({left, right} = parm);
                if (left.type === 'Identifier') {
                  lParmNames.push(left.name);
                }
                if (right.type === 'Identifier') {
                  this.addUsed(right.name);
                } else {
                  this.walkTree(right, level + 1);
                }
            }
          }
        }
        this.context.beginScope('<unknown>', lParmNames);
        this.walkTree(node.params, level + 1);
        this.walkTree(node.body, level + 1);
        this.context.endScope();
        break;
      case 'ImportDeclaration':
        ({specifiers, source, importKind} = node);
        if ((importKind === 'value') && (source.type === 'StringLiteral')) {
          lib = source.value; // e.g. '@jdeighan/coffee-utils'
          for (l = 0, len3 = specifiers.length; l < len3; l++) {
            hSpec = specifiers[l];
            ({type, imported, local, importKind} = hSpec);
            if ((type === 'ImportSpecifier') && defined(imported) && (imported.type === 'Identifier')) {
              this.addImport(imported.name, lib);
            }
          }
        }
        break;
      case 'NewExpression':
        if (node.callee.type === 'Identifier') {
          this.addUsed(node.callee.name);
        }
        ref2 = node.arguments;
        for (m = 0, len4 = ref2.length; m < len4; m++) {
          arg = ref2[m];
          if (arg.type === 'Identifier') {
            this.addUsed(arg.name);
          } else {
            this.walkSubtree(arg);
          }
        }
        break;
      case 'MemberExpression':
        ({object} = node);
        if (object.type === 'Identifier') {
          this.addUsed(object.name);
        }
        this.walkTree(object);
        break;
      case 'ReturnStatement':
        ({argument} = node);
        if (defined(argument)) {
          if (argument.type === 'Identifier') {
            this.addUsed(argument.name);
          } else {
            this.walkTree(argument);
          }
        }
    }
    dbgReturn("ASTWalker.visit");
  }

  // ..........................................................
  check(name) {
    assert(nonEmpty(name), "empty name");
  }

  // ..........................................................
  barfAST(filePath, hOptions = {}) {
    var astCopy, full, lSortBy;
    ({full} = getOptions(hOptions));
    lSortBy = words("type params body left right");
    if (full) {
      return barf(filePath, toTAML(this.ast, {
        sortKeys: lSortBy
      }));
    } else {
      astCopy = deepCopy(this.ast);
      removeKeys(astCopy, words('start end extra declarations loc range tokens comments', 'assertions implicit optional async generato hasIndentedBody'));
      return barf(filePath, toTAML(astCopy, {
        sortKeys: lSortBy
      }));
    }
  }

};
