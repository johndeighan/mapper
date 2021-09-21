// Generated by CoffeeScript 2.6.0
// sass.coffee
var convert;

import {
  strict as assert
} from 'assert';

import sass from 'sass';

import {
  undef,
  isComment
} from '@jdeighan/coffee-utils';

import {
  StringInput
} from '@jdeighan/string-input';

convert = true;

// ---------------------------------------------------------------------------
export var convertSASS = function(flag) {
  convert = flag;
};

// ---------------------------------------------------------------------------
export var SassMapper = class SassMapper extends StringInput {
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
export var sassify = function(text) {
  var newtext, oInput, result;
  oInput = new SassMapper(text);
  newtext = oInput.getAllText();
  if (!convert) {
    return newtext;
  }
  result = sass.renderSync({
    data: newtext,
    indentedSyntax: true,
    indentType: "tab"
  });
  return result.css.toString();
};
