// Generated by CoffeeScript 2.7.0
// sass.coffee
var convert;

import sass from 'sass';

import {
  assert,
  undef
} from '@jdeighan/coffee-utils';

import {
  isComment
} from '@jdeighan/mapper/utils';

import {
  Mapper
} from '@jdeighan/mapper';

convert = true;

// ---------------------------------------------------------------------------
export var convertSASS = function(flag) {
  convert = flag;
};

// ---------------------------------------------------------------------------
export var SassMapper = class SassMapper extends Mapper {
  // --- only removes comments
  mapLine(line, level) {
    if (isComment(line)) {
      return undef;
    } else {
      return line;
    }
  }

};

// ---------------------------------------------------------------------------
export var sassify = function(block, source) {
  var newblock, oInput, result;
  oInput = new SassMapper(block, source);
  newblock = oInput.getBlock();
  if (!convert) {
    return newblock;
  }
  result = sass.renderSync({
    data: newblock,
    indentedSyntax: true,
    indentType: "tab"
  });
  return result.css.toString();
};
