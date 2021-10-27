// Generated by CoffeeScript 2.6.1
// heredoc.coffee
var lAllHereDocs, qesc;

import {
  undef,
  pass,
  croak,
  escapeStr
} from '@jdeighan/coffee-utils';

import {
  firstLine,
  remainingLines
} from '@jdeighan/coffee-utils/block';

import {
  isTAML,
  taml
} from '@jdeighan/string-input/taml';

lAllHereDocs = [];

// ---------------------------------------------------------------------------
export var mapHereDoc = function(block) {
  var heredoc, i, len;
  for (i = 0, len = lAllHereDocs.length; i < len; i++) {
    heredoc = lAllHereDocs[i];
    if (heredoc.isMyHereDoc(block)) {
      return heredoc.map(block);
    }
  }
  return croak("No valid heredoc type found");
};

// ---------------------------------------------------------------------------
export var addHereDocType = function(obj) {
  lAllHereDocs.unshift(obj);
};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
export var BaseHereDoc = class BaseHereDoc {
  isMyHereDoc(block) {
    return true;
  }

  // --- Return a string that JavaScript will interpret as a value
  map(block) {
    return '"' + qesc(block) + '"';
  }

};

// ---------------------------------------------------------------------------
export var BlockHereDoc = class BlockHereDoc extends BaseHereDoc {
  isMyHereDoc(block) {
    return firstLine(block) === '$$$';
  }

  map(block) {
    return '"' + qesc(remainingLines(block)) + '"';
  }

};

// ---------------------------------------------------------------------------
export var OneLineHereDoc = class OneLineHereDoc extends BaseHereDoc {
  isMyHereDoc(block) {
    return block.indexOf('...') === 0;
  }

  map(block) {
    // --- replace all runs of whitespace with single space char
    block = block.replace(/\s+/gs, ' ');
    return '"' + qesc(block.substr(3)) + '"';
  }

};

// ---------------------------------------------------------------------------
export var TAMLHereDoc = class TAMLHereDoc extends BaseHereDoc {
  isMyHereDoc(block) {
    return isTAML(block);
  }

  map(block) {
    return JSON.stringify(taml(block));
  }

};

// ---------------------------------------------------------------------------
export var isFunctionHeader = function(str) {
  return str.match(/^(?:([A-Za-z_][A-Za-z0-9_]*)\s*=\s*)?\(\s*([A-Za-z_][A-Za-z0-9_]*(?:,\s*[A-Za-z_][A-Za-z0-9_]*)*)?\)\s*->\s*$/); // optional function name
// optional parameters
};

export var FuncHereDoc = class FuncHereDoc extends BaseHereDoc {
  isMyHereDoc(block) {
    return isFunctionHeader(firstLine(block));
  }

  map(block, lMatches = undef) {
    var _, funcName, strParms;
    if (!lMatches) {
      lMatches = this.isMyHereDoc(block);
    }
    block = remainingLines(block);
    [_, funcName, strParms] = lMatches;
    if (!strParms) {
      strParms = '';
    }
    if (funcName) {
      return `${funcName} = (${strParms}) -> ${block}`;
    } else {
      return `(${strParms}) -> ${block}`;
    }
  }

};

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
qesc = function(block) {
  var hEsc;
  hEsc = {
    "\n": "\\n",
    "\t": "\\t",
    "\"": "\\\""
  };
  return escapeStr(block, hEsc);
};

// ---------------------------------------------------------------------------
lAllHereDocs.push(new BlockHereDoc());

lAllHereDocs.push(new TAMLHereDoc());

lAllHereDocs.push(new OneLineHereDoc());

lAllHereDocs.push(new FuncHereDoc());

lAllHereDocs.push(new BaseHereDoc());
