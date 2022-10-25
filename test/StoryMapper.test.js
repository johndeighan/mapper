// Generated by CoffeeScript 2.7.0
// StoryMapper.test.coffee
var StoryTester, storyTester;

import {
  UnitTester,
  tester
} from '@jdeighan/unit-tester';

import {
  map
} from '@jdeighan/mapper';

import {
  StoryMapper
} from '@jdeighan/mapper/story';

StoryTester = class StoryTester extends UnitTester {
  transformValue(block) {
    return map(import.meta.url, block, StoryMapper);
  }

};

storyTester = new StoryTester();

storyTester.equal(15, 'key: 53', 'key: 53');

storyTester.equal(16, '"hey, there"', '"hey, there"');

storyTester.equal(17, 'eng: "hey, there"', 'eng: \'"hey, there"\'');

storyTester.equal(18, "eng: 'hey, there'", "eng: '''hey, there'''");