// Generated by CoffeeScript 2.6.1
// Translator.coffee
var combine, hasOverlap;

import {
  undef,
  assert,
  isEmpty,
  nonEmpty
} from '@jdeighan/coffee-utils';

import {
  LOG
} from '@jdeighan/coffee-utils/log';

import {
  debug
} from '@jdeighan/coffee-utils/debug';

import {
  slurpTAML
} from '@jdeighan/mapper/taml';

// ---------------------------------------------------------------------------
export var Translator = class Translator {
  constructor(dictPath = undef) {
    debug("enter Translator()");
    this.hDict = {};
    if (dictPath) {
      this.load(dictPath);
    }
    debug("return from Translator()", this.hDict);
  }

  // ..........................................................
  translate(word) {
    return this.hDict[word.toLowerCase()];
  }

  // ..........................................................
  findWords(sent, lPhrases = []) {
    var doTrans, func, i, lFound, len1, newString, phrase, pos, self, trans;
    // --- lPhrases should have list of [<string>, <translation> ]
    // --- returns [ [<word>, <trans>, <startPos>, <endPos>], .. ]
    debug("enter findWords()", sent);
    if (nonEmpty(lPhrases)) {
      debug("lPhrases", lPhrases);
    }
    lFound = [];
    for (i = 0, len1 = lPhrases.length; i < len1; i++) {
      [phrase, trans] = lPhrases[i];
      pos = sent.indexOf(phrase);
      if (pos > -1) {
        lFound.push([phrase, trans, pos, pos + phrase.length]);
      }
    }
    self = this;
    doTrans = this.translate;
    func = function(match, start) {
      var end;
      end = start + match.length;
      if (trans = doTrans.call(self, match)) {
        if (!hasOverlap(start, end, lFound)) {
          lFound.push([match, trans, start, end]);
        }
      }
      return match;
    };
    newString = sent.replace(/\w+/g, func);
    debug("return from findWords()", lFound);
    return lFound;
  }

  // ..........................................................
  load(dictPath) {
    var epos, ext, key, nKeys, pos, ref, trans, word;
    debug(`enter load('${dictPath}')`);
    ref = slurpTAML(dictPath);
    for (key in ref) {
      trans = ref[key];
      pos = key.indexOf('(');
      if (pos === -1) {
        this.hDict[key] = trans;
      } else {
        word = key.substring(0, pos);
        this.hDict[word] = trans;
        epos = key.indexOf(')', pos);
        ext = key.substring(pos + 1, epos);
        this.hDict[combine(word, ext)] = trans;
        pos = key.indexOf('(', epos);
        while (pos !== -1) {
          epos = key.indexOf(')', pos);
          ext = key.substring(pos + 1, epos);
          this.hDict[combine(word, ext)] = trans;
          pos = key.indexOf('(', epos);
        }
      }
    }
    nKeys = Object.keys(this.hDict).length;
    debug(`${nKeys} words loaded`);
    debug("return from load()");
  }

};

// ---------------------------------------------------------------------------
hasOverlap = function(start, end, lFound) {
  var _, i, lInfo, len1, pEnd, pStart;
  assert(start <= end, "hasOverlap(): Bad positions");
  for (i = 0, len1 = lFound.length; i < len1; i++) {
    lInfo = lFound[i];
    [_, _, pStart, pEnd] = lInfo;
    assert(pStart <= pEnd, "hasOverlap(): Bad phrase positions");
    if ((start <= pEnd) && (end >= pStart)) {
      return true;
    }
  }
  return false;
};

// ---------------------------------------------------------------------------
combine = function(word, ext) {
  var len;
  if (ext.indexOf('--') === 0) {
    len = word.length;
    return word.substring(0, len - 2) + ext.substring(2);
  } else if (ext.indexOf('-') === 0) {
    len = word.length;
    return word.substring(0, len - 1) + ext.substring(1);
  }
  return word + ext;
};
