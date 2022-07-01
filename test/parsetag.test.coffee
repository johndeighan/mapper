# parsetag.test.coffee

import {UnitTesterNorm, simple} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {parsetag, tag2str} from '@jdeighan/mapper/parsetag'

# ---------------------------------------------------------------------------

(() ->

	class TagTester extends UnitTesterNorm

		transformValue: (input) ->
			return parsetag(input)

	tester = new TagTester()

	tester.equal 18, 'p', {
		type: 'tag',
		tag: 'p',
		}

	tester.equal 23, 'p.class1', {
		type: 'tag',
		tag: 'p',
		hAttr: {
			class: {value: 'class1', quote: '"'},
			}
		}

	tester.equal 31, 'p.class1.class2', {
		type: 'tag',
		tag: 'p',
		hAttr: {
			class: {value: 'class1 class2', quote: '"' },
			}
		}

	tester.equal 39, 'p border=yes', {
		type: 'tag',
		tag: 'p',
		hAttr: {
			border: {value: 'yes', quote: '' },
			}
		}

	tester.equal 47, 'p bind:border={var}', {
		type: 'tag',
		tag: 'p',
		hAttr: {
			'bind:border': {value: 'var', quote: '{' },
			}
		}

	tester.equal 55, 'myCanvas = canvas width=32 height=32', {
		type: 'tag',
		tag: 'canvas',
		hAttr: {
			width:  {value: '32', quote: '' },
			height: {value: '32', quote: '' },
			'bind:this': {value: 'myCanvas', quote: '{'},
			}
		}

	tester.equal 65, 'p border="yes"', {
		type: 'tag',
		tag: 'p',
		hAttr: {
			border: { value: 'yes', quote: '"' },
			}
		}

	tester.equal 73, "p border='yes'", {
		type: 'tag',
		tag: 'p',
		hAttr: {
			border: {value: 'yes', quote: "'" },
			}
		}

	tester.equal 81, 'p border="yes" this is a paragraph', {
		type: 'tag',
		tag: 'p',
		hAttr: {
			border: { value: 'yes', quote: '"' },
			}
		containedText: 'this is a paragraph',
		}

	tester.equal 90, 'p border="yes" "this is a paragraph"', {
		type: 'tag',
		tag: 'p',
		hAttr: {
			border: { value: 'yes', quote: '"' },
			}
		containedText: 'this is a paragraph',
		}

	tester.equal 99, 'p.nice.x border=yes class="abc def" "a paragraph"', {
		type: 'tag',
		tag: 'p',
		hAttr: {
			border: { value: 'yes', quote: '' },
			class:  { value: 'nice x abc def', quote: '"' },
			}
		containedText: 'a paragraph',
		}

	tester.equal 109, 'img href="file.ext" alt="a description"  ', {
		type: 'tag',
		tag: 'img',
		hAttr: {
			href: { value: 'file.ext', quote: '"' },
			alt:  { value: 'a description', quote: '"' },
			}
		}

	tester.equal 118, 'h1 class="desc" The syntax is nice', {
		type: 'tag',
		tag: 'h1',
		hAttr: {
			class: { value: 'desc', quote: '"' },
			},
		containedText: 'The syntax is nice',
		}

	tester.equal 127, 'h1.desc The syntax is nice', {
		type: 'tag',
		tag: 'h1',
		hAttr: {
			class: { value: 'desc', quote: '"' },
			},
		containedText: 'The syntax is nice',
		}

	tester.equal 136, 'div:markdown', {
		type: 'tag',
		tag: 'div',
		subtype: 'markdown',
		hAttr: {
			class: { value: 'markdown', quote: '"' },
			},
		}

	tester.equal 145, 'div:markdown.desc # Title', {
		type: 'tag',
		tag: 'div',
		subtype: 'markdown',
		hAttr: {
			class: { value: 'markdown desc', quote: '"' },
			},
		containedText: '# Title',
		}

	tester.equal 155, 'svelte:head', {
		type: 'tag',
		tag: 'svelte:head',
		}

	tester.equal 160, 'img {src} alt="dance"', {
		type: 'tag'
		tag: 'img'
		hAttr: {
			src: {shorthand: true, value: 'src'}
			alt: {value: 'dance', quote: '"'}
			}
		}

	)()

# ---------------------------------------------------------------------------

(() ->

	class TagTester extends UnitTesterNorm

		transformValue: (input) ->
			return tag2str(input)

	tester = new TagTester()

	tester.equal 182, {
		type: 'tag',
		tag: 'p',
		}, "<p>"

	tester.equal 187, {
		type: 'tag',
		tag: 'p',
		hAttr: {
			class: { value: 'error', quote: '"' },
			},
		}, '<p class="error">'

	tester.equal 195, {
		type: 'tag',
		tag: 'p',
		hAttr: {
			class: { value: 'myclass', quote: '{' },
			},
		}, '<p class={myclass}>'

	tester.equal 203, {
		type: 'tag',
		tag: 'svelte:head',
		}, '<svelte:head>'

	tester.equal 208, {
		type: 'tag'
		tag: 'img'
		hAttr: {
			src: {shorthand: true, value: 'src'}
			alt: {value: 'dance', quote: '"'}
			}
		}, '<img {src} alt="dance">'

	)()

# ---------------------------------------------------------------------------
# --- Test end tags

(() ->

	class TagTester extends UnitTesterNorm

		transformValue: (input) ->
			return tag2str(input, 'end')

	tester = new TagTester()

	tester.equal 231, {
		type: 'tag',
		tag: 'p',
		}, "</p>"

	tester.equal 236, {
		type: 'tag',
		tag: 'p',
		hAttr: {
			class: { value: 'error', quote: '"' },
			},
		}, '</p>'

	tester.equal 244, {
		type: 'tag',
		tag: 'p',
		hAttr: {
			class: { value: 'myclass', quote: '{' },
			},
		}, '</p>'

	tester.equal 252, {
		type: 'tag',
		tag: 'svelte:head',
		}, '</svelte:head>'

	)()
