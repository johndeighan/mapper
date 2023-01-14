// Generated by CoffeeScript 2.7.0
// markdown.coffee
var stripComments;

import {
  marked
} from 'marked';

import {
  undef,
  defined,
  OL,
  isEmpty,
  nonEmpty,
  isString,
  toArray,
  isHashComment
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
  dbgReturn
} from '@jdeighan/base-utils/debug';

import {
  undented
} from '@jdeighan/coffee-utils/indent';

import {
  svelteHtmlEsc
} from '@jdeighan/coffee-utils/svelte';

import {
  TreeMapper
} from '@jdeighan/mapper/tree';

// ---------------------------------------------------------------------------
stripComments = function(block) {
  var i, lLines, len, line, ref;
  lLines = [];
  ref = toArray(block);
  for (i = 0, len = ref.length; i < len; i++) {
    line = ref[i];
    if (nonEmpty(line) && !isHashComment(line)) {
      lLines.push(line);
    }
  }
  return lLines.join("\n");
};

// ---------------------------------------------------------------------------
export var markdownify = function(block) {
  var html, result;
  dbgEnter("markdownify", block);
  assert(isString(block), "block is not a string");
  html = marked.parse(undented(stripComments(block)), {
    grm: true,
    headerIds: false
  });
  dbg("marked returned", html);
  result = svelteHtmlEsc(html);
  dbgReturn("markdownify", result);
  return result;
};
