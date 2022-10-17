// Generated by CoffeeScript 2.7.0
// markdown.coffee
var stripComments;

import {
  marked
} from 'marked';

import {
  LOG,
  LOGVALUE,
  assert,
  croak,
  debug
} from '@jdeighan/exceptions';

import {
  undef,
  defined,
  OL,
  isEmpty,
  nonEmpty,
  isString
} from '@jdeighan/coffee-utils';

import {
  blockToArray
} from '@jdeighan/coffee-utils/block';

import {
  undented
} from '@jdeighan/coffee-utils/indent';

import {
  svelteHtmlEsc
} from '@jdeighan/coffee-utils/svelte';

import {
  isHashComment
} from '@jdeighan/mapper/utils';

import {
  TreeMapper
} from '@jdeighan/mapper/tree';

// ---------------------------------------------------------------------------
stripComments = function(block) {
  var i, lLines, len, line, ref;
  lLines = [];
  ref = blockToArray(block);
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
  debug("enter markdownify()", block);
  assert(isString(block), "block is not a string");
  html = marked.parse(undented(stripComments(block)), {
    grm: true,
    headerIds: false
  });
  debug("marked returned", html);
  result = svelteHtmlEsc(html);
  debug("return from markdownify()", result);
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
    debug("enter SimpleMarkDownMapper.visit()", hNode);
    ({str} = hNode);
    if (str.match(/^={3,}$/) && defined(this.prevStr)) {
      result = `<h1>${this.prevStr}</h1>`;
      debug("set prevStr to undef");
      this.prevStr = undef;
      debug("return from SimpleMarkDownMapper.visit()", result);
      return result;
    } else if (str.match(/^-{3,}$/) && defined(this.prevStr)) {
      result = `<h2>${this.prevStr}</h2>`;
      debug("set prevStr to undef");
      this.prevStr = undef;
      debug("return from SimpleMarkDownMapper.visit()", result);
      return result;
    } else {
      result = this.prevStr;
      debug(`set prevStr to ${OL(str)}`);
      this.prevStr = str;
      if (defined(result)) {
        result = `<p>${result}</p>`;
        debug("return from SimpleMarkDownMapper.visit()", result);
        return result;
      } else {
        debug("return undef from SimpleMarkDownMapper.visit()");
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
