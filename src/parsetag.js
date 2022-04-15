// Generated by CoffeeScript 2.6.1
  // parsetag.coffee
import {
  assert,
  undef,
  pass,
  error,
  nonEmpty
} from '@jdeighan/coffee-utils';

// ---------------------------------------------------------------------------
export var parsetag = function(line) {
  var _, all, attrName, br_val, className, dq_val, hAttr, hToken, i, lClasses, lMatches, len, modifiers, prefix, quote, ref, rest, sq_val, subtype, tagName, uq_val, value, varName;
  if (lMatches = line.match(/^(?:([A-Za-z][A-Za-z0-9_]*)\s*=\s*)?([A-Za-z][A-Za-z0-9_]*)(?:\:([a-z]+))?(\S*)\s*(.*)$/)) { // variable name
    // variable is optional
    // tag name
    // modifiers (class names, etc.)
    // attributes & enclosed text
    [_, varName, tagName, subtype, modifiers, rest] = lMatches;
    if ((tagName === 'svelte') && subtype) {
      tagName = `${tagName}:${subtype}`;
      subtype = undef;
    }
  } else {
    error(`parsetag(): Invalid HTML: '${line}'`);
  }
  switch (subtype) {
    case undef:
    case '':
      pass;
      break;
    case 'startup':
    case 'onmount':
    case 'ondestroy':
      if (tagName !== 'script') {
        error(`parsetag(): subtype '${subtype}' only allowed with script`);
      }
      break;
    case 'markdown':
    case 'sourcecode':
      if (tagName !== 'div') {
        error("parsetag(): subtype 'markdown' only allowed with div");
      }
  }
  // --- Handle classes added via .<class>
  lClasses = [];
  if (subtype === 'markdown') {
    lClasses.push('markdown');
  }
  if (modifiers) {
    // --- currently, these are only class names
    while (lMatches = modifiers.match(/^\.([A-Za-z][A-Za-z0-9_]*)/)) {
      [all, className] = lMatches;
      lClasses.push(className);
      modifiers = modifiers.substring(all.length);
    }
    if (modifiers) {
      error(`parsetag(): Invalid modifiers in '${line}'`);
    }
  }
  // --- Handle attributes
  hAttr = {}; // { name: { value: <value>, quote: <quote> }, ... }
  if (varName) {
    hAttr['bind:this'] = {
      value: varName,
      quote: '{'
    };
  }
  if (rest) {
    while (lMatches = rest.match(/^(?:(?:(bind|on):)?([A-Za-z][A-Za-z0-9_]*))=(?:\{([^}]*)\}|"([^"]*)"|'([^']*)'|([^"'\s]+))\s*/)) { // prefix
      // attribute name
      // attribute value
      [all, prefix, attrName, br_val, dq_val, sq_val, uq_val] = lMatches;
      if (br_val) {
        value = br_val;
        quote = '{';
      } else {
        assert(prefix == null, "prefix requires use of {...}");
        if (dq_val) {
          value = dq_val;
          quote = '"';
        } else if (sq_val) {
          value = sq_val;
          quote = "'";
        } else {
          value = uq_val;
          quote = '';
        }
      }
      if (prefix) {
        attrName = `${prefix}:${attrName}`;
      }
      if (attrName === 'class') {
        ref = value.split(/\s+/);
        for (i = 0, len = ref.length; i < len; i++) {
          className = ref[i];
          lClasses.push(className);
        }
      } else {
        if (hAttr.attrName != null) {
          error(`parsetag(): Multiple attributes named '${attrName}'`);
        }
        hAttr[attrName] = {value, quote};
      }
      rest = rest.substring(all.length);
    }
  }
  // --- The rest is contained text
  rest = rest.trim();
  if (lMatches = rest.match(/^['"](.*)['"]$/)) {
    rest = lMatches[1];
  }
  // --- Add class attribute to hAttr if there are classes
  if (lClasses.length > 0) {
    hAttr.class = {
      value: lClasses.join(' '),
      quote: '"'
    };
  }
  // --- If subtype == 'startup'
  if (subtype === 'startup') {
    if (!hAttr.context) {
      hAttr.context = {
        value: 'module',
        quote: '"'
      };
    }
  }
  // --- Build the return value
  hToken = {
    type: 'tag',
    tag: tagName
  };
  if (subtype) {
    hToken.subtype = subtype;
  }
  if (nonEmpty(hAttr)) {
    hToken.hAttr = hAttr;
  }
  // --- Is there contained text?
  if (rest) {
    hToken.containedText = rest;
  }
  return hToken;
};

// ---------------------------------------------------------------------------
export var isBlockTag = function(hTag) {
  var subtype, tag;
  ({tag, subtype} = hTag);
  return (tag === 'script') || (tag === 'style') || (tag === 'pre') || ((tag === 'div') && (subtype === 'markdown')) || ((tag === 'div') && (subtype === 'sourcecode'));
};

// ---------------------------------------------------------------------------
// --- export only for unit testing
export var attrStr = function(hAttr) {
  var attrName, bquote, equote, i, len, quote, ref, str, value;
  if (!hAttr) {
    return '';
  }
  str = '';
  ref = Object.getOwnPropertyNames(hAttr);
  for (i = 0, len = ref.length; i < len; i++) {
    attrName = ref[i];
    ({value, quote} = hAttr[attrName]);
    if (quote === '{') {
      bquote = '{';
      equote = '}';
    } else {
      bquote = equote = quote;
    }
    str += ` ${attrName}=${bquote}${value}${equote}`;
  }
  return str;
};

// ---------------------------------------------------------------------------
export var tag2str = function(hToken) {
  var str;
  str = `<${hToken.tag}`;
  if (nonEmpty(hToken.hAttr)) {
    str += attrStr(hToken.hAttr);
  }
  str += '>';
  return str;
};
