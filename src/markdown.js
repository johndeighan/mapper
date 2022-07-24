// Generated by CoffeeScript 2.7.0
// markdown.coffee
var stripComments;

import {
  marked
} from 'marked';

import {
  assert,
  undef,
  defined,
  OL,
  isEmpty,
  nonEmpty,
  isString
} from '@jdeighan/coffee-utils';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

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
  Mapper
} from '@jdeighan/mapper';

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
export var SimpleMarkDownMapper = class SimpleMarkDownMapper extends Mapper {
  init() {
    this.prevLine = undef;
  }

  // ..........................................................
  mapEmptyLine(hLine) {
    return undef;
  }

  // ..........................................................
  mapComment(hLine) {
    return undef;
  }

  // ..........................................................
  map(hLine) {
    var line, result;
    debug("enter SimpleMarkDownMapper.map()", hLine);
    assert(defined(hLine), "hLine is undef");
    ({line} = hLine);
    assert(isString(line), "line not a string");
    if (line.match(/^={3,}$/) && defined(this.prevLine)) {
      result = `<h1>${this.prevLine}</h1>`;
      debug("set prevLine to undef");
      this.prevLine = undef;
      debug("return from SimpleMarkDownMapper.map()", result);
      return result;
    } else {
      result = this.prevLine;
      debug(`set prevLine to ${OL(line)}`);
      this.prevLine = line;
      if (defined(result)) {
        result = `<p>${result}</p>`;
        debug("return from SimpleMarkDownMapper.map()", result);
        return result;
      } else {
        debug("return undef from SimpleMarkDownMapper.map()");
        return undef;
      }
    }
  }

  // ..........................................................
  endBlock() {
    if (defined(this.prevLine)) {
      return `<p>${this.prevLine}</p>`;
    } else {
      return undef;
    }
  }

};
