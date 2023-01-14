Adapters
========

Svelte provides:

adapter-auto
adapter-static
adapter-node
adapter-cloudflare
adapter-netlify
adapter-vercel

deploy to Vercel
================

adapter-auto, which is installed will do everything

deploy to Keroku
================

We have to install and use the node adapter:

```bash
$ npm install @sveltejs/adapter-node@next
```

Then switch the svelte config file to use this adapter:

```coffeescript
import adapter from '@sveltejs/adapter-node'
```

Put a `start` script into our `package.json` file:

```json
	"start": "node build/index.js",
```

Next, add, commit and push:

```bash
$ git add -A
$ git commit -m "switch to node adapter"
$ git push
```

Get on the Heroku web site and:

TO DO

deploy to surge
================

We have to install and use the static adapter:

```bash
$ npm install @sveltejs/adapter-static@next
```

Then switch the svelte config file to use this adapter:

```coffeescript
import adapter from '@sveltejs/adapter-static'
```

Next, add, commit and push:

```bash
$ git add -A
$ git commit -m "switch to node adapter"
$ git push
```

Build the static site:

```bash
$ npm run build
```

Run the surge executable to deploy it:


