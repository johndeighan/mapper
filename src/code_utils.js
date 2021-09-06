// Generated by CoffeeScript 2.5.1
  // code_utils.coffee
import {
  strict as assert
} from 'assert';

import CoffeeScript from 'coffeescript';

import {
  say,
  undef,
  pass,
  croak,
  isEmpty,
  nonEmpty,
  isComment,
  isString,
  unitTesting,
  escapeStr,
  firstLine,
  isHash,
  arrayToString
} from '@jdeighan/coffee-utils';

import {
  slurp,
  barf,
  mydir,
  pathTo
} from '@jdeighan/coffee-utils/fs';

import {
  splitLine
} from '@jdeighan/coffee-utils/indent';

import {
  debug,
  debugging,
  startDebugging,
  endDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  PLLParser
} from '@jdeighan/string-input';

import {
  ASTWalker
} from '@jdeighan/string-input/tree';

import {
  tamlStringify
} from '@jdeighan/string-input/convert';

// ---------------------------------------------------------------------------
export var getNeededImports = function(code, hOptions = {}) {
  var hMissing, hNeeded, hSymbols, i, j, lImports, len, len1, lib, ref, ref1, sym, symbols;
  // --- Valid options:
  //        dumpfile: <filepath>   - where to dump ast
  //        debug: <bool>          - turn on debugging
  // --- returns lImports
  debug("enter getNeededImports()");
  hMissing = getMissingSymbols(code, hOptions);
  if (isEmpty(hMissing)) {
    return [];
  }
  hSymbols = getAvailSymbols();
  if (isEmpty(hSymbols)) {
    return [];
  }
  hNeeded = {}; // { <lib>: [<symbol>, ...], ...}
  ref = Object.keys(hMissing);
  for (i = 0, len = ref.length; i < len; i++) {
    sym = ref[i];
    if (lib = hSymbols[sym]) {
      if (hNeeded[lib]) {
        hNeeded[lib].push(sym);
      } else {
        hNeeded[lib] = [sym];
      }
    }
  }
  lImports = [];
  ref1 = Object.keys(hNeeded);
  for (j = 0, len1 = ref1.length; j < len1; j++) {
    lib = ref1[j];
    symbols = hNeeded[lib].join(',');
    lImports.push(`import {${symbols}} from '${lib}'`);
  }
  debug("return from getNeededImports()");
  return arrayToString(lImports);
};

// ---------------------------------------------------------------------------
// export to allow unit testing
export var getMissingSymbols = function(code, hOptions = {}) {
  var ast, err, hMissingSymbols, walker;
  // --- Valid options:
  //        dumpfile: <filepath>   - where to dump ast
  //        debug: <bool>          - turn on debugging
  if (hOptions.debug) {
    startDebugging;
  }
  debug("enter getMissingSymbols()");
  try {
    debug(code, "COMPILE CODE:");
    ast = CoffeeScript.compile(code, {
      ast: true
    });
    assert(ast != null, "getMissingSymbols(): ast is empty");
  } catch (error) {
    err = error;
    say(`ERROR in getMissingSymbols(): ${err.message}`);
    say(code, "CODE:");
  }
  walker = new ASTWalker(ast);
  hMissingSymbols = walker.getMissingSymbols();
  if (hOptions.debug) {
    endDebugging;
  }
  if (hOptions.dumpfile) {
    barf(hOptions.dumpfile, "AST:\n" + tamlStringify(walker.ast));
  }
  debug("return from getMissingSymbols()");
  return hMissingSymbols;
};

// ---------------------------------------------------------------------------
// export to allow unit testing
export var getAvailSymbols = function() {
  var SymbolParser, body, contents, filepath, hItem, hSymbols, i, j, k, len, len1, len2, lib, ref, searchFromDir, sym, tree;
  debug("enter getAvailSymbols()");
  searchFromDir = mydir(import.meta.url);
  debug(`search for .symbols from '${searchFromDir}'`);
  filepath = pathTo('.symbols', searchFromDir, 'up');
  if (filepath == null) {
    return {};
  }
  debug(`.symbols file found at '${filepath}'`);
  contents = slurp(filepath);
  SymbolParser = class SymbolParser extends PLLParser {
    mapString(line, level) {
      if (level === 0) {
        return line;
      } else if (level === 1) {
        return line.split(/\s+/).filter(function(s) {
          return nonEmpty(s);
        });
      } else {
        return croak(`Bad .symbols file - level = ${level}`);
      }
    }

  };
  tree = new SymbolParser(contents).getTree();
  hSymbols = {}; // { <symbol>: <lib>, ... }
  for (i = 0, len = tree.length; i < len; i++) {
    ({
      node: lib,
      body
    } = tree[i]);
    for (j = 0, len1 = body.length; j < len1; j++) {
      hItem = body[j];
      ref = hItem.node;
      for (k = 0, len2 = ref.length; k < len2; k++) {
        sym = ref[k];
        assert(hSymbols[sym] == null, `dup symbol: '${sym}'`);
        hSymbols[sym] = lib;
      }
    }
  }
  debug("return from getAvailSymbols()");
  return hSymbols;
};
