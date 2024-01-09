# Context.test.coffee

import {utest} from '@jdeighan/unit-tester'
import {Context} from '@jdeighan/mapper/context'

context = new Context()
context.add 'main', 'func'

context.beginScope()
context.add 'func2', 'func3'

utest.truthy 11, context.has('main')
utest.truthy 12, context.has('func')
utest.truthy 13, context.has('func3')
utest.falsy  14, context.has('notthere')

context.endScope()

utest.truthy 17, context.has('main')
utest.truthy 18, context.has('func')
utest.falsy  19, context.has('func3')
utest.falsy  20, context.has('notthere')
