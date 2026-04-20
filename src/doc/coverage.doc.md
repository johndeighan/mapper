coverage
========

This document tells you how to add unit tests, then
figure out how well the tests cover the functions
in the corresponding library.

Create these two files:
	<stub>.lib.civet
	<stub>.lib.test.civet

The first is the library file itself. You can ensure
that it compiles with:

	deno run -A npm:@danielx/civet --inline-map -o .ts -c <stub>.lib.civet

Hint: in bash shell, set up an alias

Next, run the unit test with:

	deno run -A npm:@danielx/civet --inline-map -o .ts -c $1.civet
	deno test -A --coverage-raw-data-only src/test/$1.lib.test.ts
