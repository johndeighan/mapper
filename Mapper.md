class Mapper
=================

A Mapper object is a subclass of Getter, and is therefore
constructed from a block (i.e. a multi-line string) and an optional source.

It has the following features:

- sets/maintains variables DIR, FILE, LINE
- treats these as "special" items:
	- empty lines, i.e. where isEmpty(line) returns true
	- comments, i.e. \s* # (end of line | whitespace char)
	- commands, i.e. \s* # <identifier>
- provides overridable methods:
	- isEmptyLine(line) - defaults to isEmpty(line)
	- handleEmptyLine() - by default, retains empty lines as ''
	- isComment(line) - default as above
	- handleComment(line) - by default, retains comments as is
	- isCmd(line) - default as above
	- handleCmd(h) - handles #define, else croaks
