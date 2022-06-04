class TreeWalker
=================

A TreeWalker object is a subclass of Mapper

To create a subclass of PLLMapper:

1. override @mapStr() to map a line (minus indent) to anything
2. override @unmapObj() to map anything to a string
3. To allow doMap() to construct a block, override:
	beginWalk()
	visit(uobj)
	endVisit(uobj)
	endWalk()


It has the following features:

- removes empty lines
- retains comments as is
- handles extension lines
- handles HEREDOCs
- provides method walk() to walk the tree


Additionally:
- to handle empty lines differently, override handleEmptyLine()
- to handle comments differently, override handleComment()
- to define new commands, override handleCmd()

1. Removes blank lines from the block by default, but this
	behavior can be modified by overriding method handleEmptyLine()

2. Retains comments from the block by default, but this behavior
	can be modified by overriding method handleComment()

3. Replaces built-in variables __LINE__, __FILE__ and __DIR__ with the
	current line number, current file, and directory that the current
	file is in.

4. Understands the command #define <name> <value> and sets the corresponding
	variable. <name> must start and end with a double underscore, and
	otherwise consist of only capital letters.

5. Replaces variables defined by the #define command, e.g. if this command
	is encountered: `#define NAME John`, after that all instances of
	'__NAME__' will be replaced by 'John'. Note that variables names must
	consist of 3 or more capital letters, but cannot be 'LINE', 'FILE'
	or 'DIR'.

6. If a line has an indentation level of N, then all lines following it
	that have an indentation level of N+2 or greater are considered to be
	continuation lines and are appended to the original line, with a space
	character separator, before it is passed to mapLine().

7. Handles HEREDOCs automatically. When a line contains one or more "<<<"
	strings, for each one it fetches all following lines at a greater level
	(but remember #2 above, which is done first), then interprets that block
	as a HEREDOC section, which results in "<<<" being replaced by a string
	that generates that object (if it's a string, it will be surrounded by
	quote marks).

8. To modify its behavior, override mapString(line, level), not mapLine()
	because mapLine() implements the above features.

NOTE: You can add new types of HEREDOC sections by defining a new class
	that includes these methods:

```text
myName() - provide the name of the new type (must be unique)
isMyHereDoc(block) - return true if this class should handle it
map(block, result) - return the object you want to replace '<<<'
	- this should return a hash with keys `obj` and `str`, where obj
		is the actual object, and str is a string which will directly
		replace the '<<<' and should compile to the same object
```

- If isMyHereDoc returns a true value, then that value will be passed
	as the 2nd parameter to map() - it can be any true value, not just
	a boolean

Once the class has been defined, you can enable that type of HEREDOC with:

```coffeescript
addHereDocType new HereDocClass()
```

7. Handles HEREDOCs automatically. When a line contains one or more "<<<"
	strings, for each one it fetches all following lines at a greater level
	(but remember #2 above, which is done first), then interprets that block
	as a HEREDOC section, which results in "<<<" being replaced by a string
	that generates that object (if it's a string, it will be surrounded by
	quote marks).


```text
myName() - provide the name of the new type (must be unique)
isMyHereDoc(block) - return true if this class should handle it
map(block, result) - return the object you want to replace '<<<'
	- this should return a hash with keys `obj` and `str`, where obj
		is the actual object, and str is a string which will directly
		replace the '<<<' and should compile to the same object
```

- If isMyHereDoc returns a true value, then that value will be passed
	as the 2nd parameter to map() - it can be any true value, not just
	a boolean

Once the class has been defined, you can enable that type of HEREDOC with:

```coffeescript
addHereDocType new HereDocClass()
```
