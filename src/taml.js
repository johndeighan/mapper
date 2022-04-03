// Generated by CoffeeScript 2.6.1
// taml.coffee
import yaml from 'js-yaml';

import {
  assert,
  undef,
  oneline,
  isString
} from '@jdeighan/coffee-utils';

import {
  untabify,
  tabify,
  splitLine
} from '@jdeighan/coffee-utils/indent';

import {
  log,
  tamlStringify
} from '@jdeighan/coffee-utils/log';

import {
  slurp,
  forEachLineInFile
} from '@jdeighan/coffee-utils/fs';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  firstLine,
  blockToArray
} from '@jdeighan/coffee-utils/block';

import {
  Mapper,
  doMap
} from '@jdeighan/mapper';

// ---------------------------------------------------------------------------
//   isTAML - is the string valid TAML?
export var isTAML = function(text) {
  return isString(text) && (firstLine(text).indexOf('---') === 0);
};

// ---------------------------------------------------------------------------
//   taml - convert valid TAML string to a JavaScript value
export var taml = function(text, hOptions = {}) {
  // --- Valid options:
  //        premapper - a subclass of Mapper
  debug(`enter taml(${oneline(text)})`);
  if (text == null) {
    debug("return undef from taml() - text is not defined");
    return undef;
  }
  // --- If a premapper is provided, use it to map the text
  if (hOptions.premapper) {
    text = doMap(hOptions.premapper, text);
  }
  assert(isTAML(text), `taml(): string ${oneline(text)} isn't TAML`);
  debug("return from taml()");
  return yaml.load(untabify(text), {
    skipInvalid: true
  });
};

// ---------------------------------------------------------------------------
//   slurpTAML - read TAML from a file
export var slurpTAML = function(filepath) {
  var contents;
  contents = slurp(filepath);
  return taml(contents);
};

// ---------------------------------------------------------------------------
// --- Plugin for a TAML HEREDOC type
export var TAMLHereDoc = class TAMLHereDoc {
  myName() {
    return 'taml';
  }

  isMyHereDoc(block) {
    return isTAML(block);
  }

  map(block) {
    var obj;
    obj = taml(block);
    return {
      obj,
      str: JSON.stringify(obj)
    };
  }

};

// ---------------------------------------------------------------------------
// A Mapper useful for stories
export var StoryMapper = class StoryMapper extends Mapper {
  mapLine(line, level) {
    var _, ident, lMatches, str;
    if (lMatches = line.match(/([A-Za-z_][A-Za-z0-9_]*)\:\s*(.+)$/)) { // identifier
      // colon
      // optional whitespace
      // a non-empty string
      [_, ident, str] = lMatches;
      if (str.match(/\d+(?:\.\d*)?$/)) {
        return line;
      } else {
        // --- surround with single quotes, double internal single quotes
        str = "'" + str.replace(/\'/g, "''") + "'";
        return `${ident}: ${str}`;
      }
    } else {
      return line;
    }
  }

};
