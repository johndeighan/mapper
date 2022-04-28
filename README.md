@jdeighan/mapper
================

This npm package provides the following libraries:

/taml:
------

	isTAML(block) - returns true if 1st line of block is '---'
	taml(block) - returns data structure that block represents
	slurpTAML(path) - returns data structure text in file represents

/markdown:
----------

	convertMarkdown(flag) - if false, markdownify just returns 1st arg
	markdownify(block) - convert markdown to HTML

NOTE: Since one or more '#' characters introduce a comment, don't do this:

```markdown
# A title
```

but, instead, do this:

```markdown
A title
=======
```

replace '=' characters with '-' characters for a level 2 heading

/sass:
------

	convertSASS(flag) - if false, sassify() just returns block
	sassify(block) - returns equivalent CSS

/builtins:
----------

	isBuiltin(name) - tells you whether the name is a JavaScript reserved
		name. The list is VERY incomplete and should probably not be
		used from outside this package.

/mapper:
--------------

This library provides 4 classes of increasing complexity:

1. [LineFetcher](./LineFetcher.md)
2. [Mapper](./Mapper.md)
3. [CieloMapper](./CieloMapper.md)

/get:
-----

	class Getter(lItems) with methods:
		- get()
		- unget(item)
		- peek()
		- skip()
		- eof()
/heredoc:
---------

	doDebug(flag) - turns on HEREDOC debugging if flag = true
	mapHereDoc(block) - interprets a HEREDOC block and returns result
	addHereDocType(obj) - add a new HEREDOC type by passing a class
		that implements methods myName(), isMyHereDoc(block) and map(block)

/func:
------

Provides class FuncHereDoc, which can be used to add a new HEREDOC
type via addHereDocType() in /heredoc

/tree:
--------------

Provides:

- [TreeMapper](./TreeMapper.md)

/walker:
--------

Implements these 3 classes:

1. [TreeWalker](./TreeWalker.md)
2. [ASTWalker](./ASTWalker.md)
3. [TreeStringifier](./TreeStringifier.md)

/symbols:
---------

Includes functions:

- `getNeededSymbols(coffeeCode, hOptions)`
- `addImports(coffeeCode, rootDir, hOptions)`
- `buildImportBlock(lNeededSymbols, rootDir, hOptions)`
- `buildImportList(lNeededSymbols, rootDir, hOptions)`
- `getAvailSymbols(rootDir, hOptions)`

/coffee:
--------

Includes functions:

- `convertCoffee(flag)`
- `coffeeExprToJS(coffeeExpr, force)`
- `coffeeCodeToJS(code, hOptions)`
- `coffeeFileToJS(srcPath, destPath, hOptions)`
- `coffeeEvalFunc(lParmNames, strBody)` - use with FuncHereDoc

/cielo:
-------

	convertCielo(flag) - if false, cieloCodeToJS() just returns block
	cieloCodeToJS(block)
	addImports()
	cieloFileToJS()
