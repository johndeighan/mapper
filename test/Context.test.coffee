# Context.test.coffee

import {truthy, falsy} from '@jdeighan/base-utils/utest'
import {Context} from '@jdeighan/mapper/context'

context = new Context()
context.add 'main', 'func'

context.beginScope()
context.add 'func2', 'func3'

truthy context.has('main')
truthy context.has('func')
truthy context.has('func3')
falsy  context.has('notthere')

context.endScope()

truthy context.has('main')
truthy context.has('func')
falsy  context.has('func3')
falsy  context.has('notthere')
