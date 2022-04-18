// Generated by CoffeeScript 2.6.1
// Translator.coffee
var combine;

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
    this.lFound = undef;
    debug("return from Translator()", this.hDict);
  }

  // ..........................................................
  translate(word) {
    return this.hDict[word.toLowerCase()];
  }

  // ..........................................................
  found(str, trans, pos, end) {
    this.lFound.push([str, trans, pos, end]);
  }

  // ..........................................................
  findWords(sent, lPhrases = []) {
    var end, func, h, i, lFound, len1, newString, phrase, start;
    // --- lPhrases should have list of {en, zh, pinyin}
    // --- returns [ [<word>, <trans>, <startPos>, <endPos>], .. ]
    debug("enter findWords()", sent);
    if (nonEmpty(lPhrases)) {
      debug("lPhrases", lPhrases);
    }
    this.lFound = [];
    for (i = 0, len1 = lPhrases.length; i < len1; i++) {
      h = lPhrases[i];
      phrase = h.en;
      start = sent.indexOf(phrase);
      if (start > -1) {
        end = start + phrase.length;
        this.found(phrase, `${h.zh} ${h.pinyin}`, start, end);
      }
    }
    // --- We need to use a "fat arrow" function here
    //     to prevent 'this' being replaced
    func = (match, start) => {
      var trans;
      end = start + match.length;
      if (trans = this.translate(match)) {
        if (!this.hasOverlap(start, end)) {
          this.found(match, trans, start, end);
        }
      }
      return match;
    };
    // --- This will find all matches - it doesn't actually replace
    newString = sent.replace(/\w+/g, func);
    lFound = this.lFound;
    this.lFound = undef;
    debug("return from findWords()", lFound);
    return lFound;
  }

  // ..........................................................
  hasOverlap(start, end) {
    var _, i, lInfo, len1, pEnd, pStart, ref;
    assert(start <= end, "hasOverlap(): Bad positions");
    ref = this.lFound;
    for (i = 0, len1 = ref.length; i < len1; i++) {
      lInfo = ref[i];
      [_, _, pStart, pEnd] = lInfo;
      assert(pStart <= pEnd, "hasOverlap(): Bad phrase positions");
      if ((start <= pEnd) && (end >= pStart)) {
        return true;
      }
    }
    return false;
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
