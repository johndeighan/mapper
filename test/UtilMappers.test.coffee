# UtilMappers.test.coffee

import {UnitTester, utest} from '@jdeighan/unit-tester'
import {map} from '@jdeighan/mapper'
import {TamlMapper, StoryMapper} from '@jdeighan/mapper/util-mappers'

# ---------------------------------------------------------------------------

class StoryTester extends UnitTester

	transformValue: (block) ->

		return map(block, StoryMapper)

storyTester = new StoryTester()

storyTester.equal 15, 'key: 53', 'key: 53'
storyTester.equal 16, '"hey, there"', '"hey, there"'
storyTester.equal 17, 'eng: "hey, there"', 'eng: \'"hey, there"\''
storyTester.equal 18, "eng: 'hey, there'", "eng: '''hey, there'''"
