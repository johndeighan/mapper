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

// ---------------------------------------------------------------------------
// --- Does not use marked!!!
//     just simulates markdown processing
export var SimpleMarkDownMapper = class SimpleMarkDownMapper extends TreeMapper {
  beginLevel(level) {
    if (level === 0) {
      this.prevStr = undef;
    }
  }

  // ..........................................................
  visit(hNode) {
    var result, str;
    dbgEnter("SimpleMarkDownMapper.visit", hNode);
    ({str} = hNode);
    if (str.match(/^={3,}$/) && defined(this.prevStr)) {
      result = `<h1>${this.prevStr}</h1>`;
      dbg("set prevStr to undef");
      this.prevStr = undef;
      dbgReturn("SimpleMarkDownMapper.visit", result);
      return result;
    } else if (str.match(/^-{3,}$/) && defined(this.prevStr)) {
      result = `<h2>${this.prevStr}</h2>`;
      dbg("set prevStr to undef");
      this.prevStr = undef;
      dbgReturn("SimpleMarkDownMapper.visit", result);
      return result;
    } else {
      result = this.prevStr;
      dbg(`set prevStr to ${OL(str)}`);
      this.prevStr = str;
      if (defined(result)) {
        result = `<p>${result}</p>`;
        dbgReturn("SimpleMarkDownMapper.visit", result);
        return result;
      } else {
        dbgReturn("SimpleMarkDownMapper.visit", undef);
        return undef;
      }
    }
  }

  // ..........................................................
  endLevel(hUser, level) {
    if ((level === 0) && defined(this.prevStr)) {
      return `<p>${this.prevStr}</p>`;
    } else {
      return undef;
    }
  }

};
