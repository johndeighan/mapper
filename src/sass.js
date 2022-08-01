// Generated by CoffeeScript 2.7.0
// sass.coffee
import sass from 'sass';

import {
  assert,
  error,
  croak
} from '@jdeighan/unit-tester/utils';

import {
  undef
} from '@jdeighan/coffee-utils';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  isHashComment
} from '@jdeighan/mapper/utils';

import {
  Mapper,
  doMap
} from '@jdeighan/mapper';

// ---------------------------------------------------------------------------
export var sassify = function(block, source) {
  var newblock, result;
  debug("enter sassify()", block, source);
  // --- NOTE: Mapper will remove comments and blank lines
  newblock = doMap(Mapper, source, block);
  debug("newblock", newblock);
  result = sass.renderSync({
    data: newblock,
    indentedSyntax: true,
    indentType: "tab"
  });
  result = result.css.toString();
  debug("return from sassify()", result);
  return result;
};
