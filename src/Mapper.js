// Generated by CoffeeScript 2.7.0
  // Mapper.coffee
import {
  assert,
  error,
  croak
} from '@jdeighan/unit-tester/utils';

import {
  undef,
  pass,
  OL,
  rtrim,
  defined,
  escapeStr,
  className,
  isString,
  isHash,
  isArray,
  isFunction,
  isIterable,
  isEmpty,
  nonEmpty,
  isSubclassOf
} from '@jdeighan/coffee-utils';

import {
  splitPrefix,
  splitLine
} from '@jdeighan/coffee-utils/indent';

import {
  LOG
} from '@jdeighan/coffee-utils/log';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  parseSource,
  slurp
} from '@jdeighan/coffee-utils/fs';

import {
  Node
} from '@jdeighan/mapper/node';

import {
  Getter
} from '@jdeighan/mapper/getter';

// ---------------------------------------------------------------------------
export var Mapper = class Mapper extends Getter {
  // --- handles #define
  //     performs const substitution
  //     splits mapping into special lines and non-special lines
  constructor(source = undef, collection = undef) {
    debug("enter Mapper()");
    super(source, collection);
    // --- These never change
    this.setConst('FILE', this.hSourceInfo.filename);
    this.setConst('DIR', this.hSourceInfo.dir);
    this.setConst('SRC', this.sourceInfoStr());
    // --- This needs to be kept updated
    this.setConst('LINE', this.lineNum);
    this.hSpecials = {};
    this.lSpecials = []; // checked in this order
    
    // --- These must be bound to a specific object when called
    this.registerSpecialType('empty', this.isEmptyLine, this.mapEmptyLine);
    this.registerSpecialType('comment', this.isComment, this.mapComment);
    this.registerSpecialType('cmd', this.isCmd, this.mapCmd);
    debug("return from Mapper()");
  }

  // ..........................................................
  registerSpecialType(type, recognizer, mapper) {
    if (!this.lSpecials.includes(type)) {
      this.lSpecials.push(type);
    }
    this.hSpecials[type] = {recognizer, mapper};
  }

  // ..........................................................
  // --- override to keep variable LINE updated
  incLineNum(inc = 1) {
    debug(`enter incLineNum(${inc})`);
    super.incLineNum(inc);
    this.setConst('LINE', this.lineNum);
    debug("return from incLineNum()");
  }

  // ..........................................................
  getItemType(hNode) {
    var i, len, recognizer, ref, str, type;
    debug("enter Mapper.getItemType()", hNode);
    ({str} = hNode);
    assert(isString(str), `str is ${OL(str)}`);
    ref = this.lSpecials;
    for (i = 0, len = ref.length; i < len; i++) {
      type = ref[i];
      recognizer = this.hSpecials[type].recognizer;
      if (recognizer.bind(this)(hNode)) {
        debug("return from getItemType()", type);
        return type;
      }
    }
    debug("return from getItemType()", undef);
    return undef;
  }

  // ..........................................................
  mapSpecial(type, hNode) {
    var h, mapper, uobj;
    debug("enter Mapper.mapSpecial()", type, hNode);
    assert(hNode instanceof Node, `hNode is ${OL(hNode)}`);
    assert(hNode.type === type, `hNode is ${OL(hNode)}`);
    h = this.hSpecials[type];
    assert(isHash(h), `Unknown type ${OL(type)}`);
    mapper = h.mapper.bind(this);
    assert(isFunction(mapper), `Bad mapper for ${OL(type)}`);
    uobj = mapper(hNode);
    debug("return from Mapper.mapSpecial()", uobj);
    return uobj;
  }

  // ..........................................................
  isEmptyLine(hNode) {
    return hNode.str === '';
  }

  // ..........................................................
  mapEmptyLine(hNode) {
    // --- default: remove empty lines
    //     return '' to keep empty lines
    return undef;
  }

  // ..........................................................
  isComment(hNode) {
    if (hNode.str.indexOf('# ') === 0) {
      hNode.uobj = {
        comment: hNode.str.substring(2).trim()
      };
      return true;
    } else {
      return false;
    }
  }

  // ..........................................................
  mapComment(hNode) {
    // --- default: remove comments
    // --- To keep comments, simply return hNode.uobj
    return undef;
  }

  // ..........................................................
  isCmd(hNode) {
    var lMatches;
    debug("enter Mapper.isCmd()");
    if (lMatches = hNode.str.match(/^\#([A-Za-z_]\w*)\s*(.*)$/)) { // name of the command
      // argstr for command
      hNode.uobj = {
        cmd: lMatches[1],
        argstr: lMatches[2]
      };
      debug("return true from Mapper.isCmd()");
      return true;
    } else {
      debug("return false from Mapper.isCmd()");
      return false;
    }
  }

  // ..........................................................
  // --- mapCmd returns a mapped object, or
  //        undef to produce no output
  // Override must 1st handle its own commands,
  //    then call the base class mapCmd
  mapCmd(hNode) {
    var _, argstr, cmd, isEnv, lMatches, name, tail;
    debug("enter Mapper.mapCmd()", hNode);
    // --- isCmd() put these keys here
    ({cmd, argstr} = hNode.uobj);
    assert(nonEmpty(cmd), "mapCmd() with empty cmd");
    switch (cmd) {
      case 'define':
        lMatches = argstr.match(/^(env\.)?([A-Za-z_][\w\.]*)(.*)$/); // name of the variable
        assert(defined(lMatches), `Bad #define cmd: ${cmd} ${argstr}`);
        [_, isEnv, name, tail] = lMatches;
        if (tail) {
          tail = tail.trim();
        }
        if (isEnv) {
          debug(`set env var ${name} to '${tail}'`);
          process.env[name] = tail;
        } else {
          debug(`set var ${name} to '${tail}'`);
          this.setConst(name, tail);
        }
        debug("return undef from Mapper.mapCmd()");
        return undef;
      default:
        // --- don't throw exception
        //     check for unknown commands in visitCmd()
        debug("return from Mapper.mapCmd()", hNode.uobj);
        return hNode.uobj;
    }
  }

  // ..........................................................
  getCmdText(hNode) {
    var argstr, cmd, func, indentedText, srcLevel, type, uobj;
    ({type, uobj, srcLevel} = hNode);
    assert(type === 'cmd', 'not a command');
    ({cmd, argstr} = uobj);
    func = function(hNode) {
      return (hNode.str === '') || (hNode.srcLevel <= srcLevel);
    };
    indentedText = this.fetchBlockUntil(func, {
      discardEndLine: false
    });
    if (nonEmpty(argstr)) {
      assert(isEmpty(indentedText), `cmd ${cmd} has both inline text and an indented block`);
      return ['argstr', argstr];
    } else {
      return ['indented', indentedText];
    }
  }

};

// ===========================================================================
export var FuncMapper = class FuncMapper extends Mapper {
  constructor(source = undef, collection = undef, func1) {
    super(source, collection);
    this.func = func1;
    assert(isFunction(this.func), "3rd arg not a function");
  }

  getBlock(hOptions = {}) {
    var block;
    block = super.getBlock(hOptions);
    return this.func(block);
  }

};

// ===========================================================================
export var map = function(source, content = undef, mapper, hOptions = {}) {
  var i, item, len, result;
  // --- Valid options:
  //        logLines
  if (isArray(mapper)) {
    result = content;
    for (i = 0, len = mapper.length; i < len; i++) {
      item = mapper[i];
      if (defined(item)) {
        result = map(source, result, item, hOptions);
      }
    }
    return result;
  }
  debug("enter map()", source, content, mapper);
  assert(defined(mapper), "Missing input class");
  if (mapper instanceof Mapper) {
    result = mapper.getBlock(hOptions);
  } else if (isSubclassOf(mapper, Mapper)) {
    mapper = new mapper(source, content);
    assert(mapper instanceof Mapper, "Mapper or subclass required");
    result = mapper.getBlock(hOptions);
  } else {
    croak("Bad mapper");
  }
  debug("return from map()", result);
  return result;
};

// ---------------------------------------------------------------------------
