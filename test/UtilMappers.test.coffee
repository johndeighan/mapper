# UtilMappers.test.coffee

import {u, equal} from '@jdeighan/base-utils/utest'
import {setDebugging} from '@jdeighan/base-utils/debug'
import {map} from '@jdeighan/mapper'
import {StoryMapper} from '@jdeighan/mapper/util-mappers'

# ---------------------------------------------------------------------------

u.transformValue = (block) => return map(block, StoryMapper)

# --- If not <ident>: <str>, return as is
equal '"hey, there"',         '"hey, there"'

# --- If value is a number, leave it as is
equal 'key: 53',              'key: 53'

# --- surround with single quotes, double internal quotes
equal 'eng: "hey, there"',    'eng: \'"hey, there"\''

equal "eng: 'hey, there'",    "eng: '''hey, there'''"
