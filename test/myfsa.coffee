# myfsa.coffee

import {undef, defined, notdefined} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {FSA} from '@jdeighan/mapper/fsa'

# ---------------------------------------------------------------------------

class MyFSA extends FSA


export getFSA = () ->

	return new FSA("""
		start   'tag'      start
		start   'if'       if1
		start   EOF        end
		if1     'tag'      start   {/if}
		if1     'elsif'    if1
		if1     EOF        end     {/if}
		if1     'else'     if2
		if2     'tag'      start   {/if}
		if2     'if'       if1     {/if}
		if2     EOF        end     {/if}
		""")
