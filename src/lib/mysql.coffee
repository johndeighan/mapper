# mysql.coffee

import util from 'util'
import mysql from 'mysql-await'
import {assert} from '@jdeighan/base-utils'
import {
	undef, defined, notdefined, LOG, LOGVALUE,
	} from '@jdeighan/coffee-utils'

export hConfig = {
	host: 'us-cdbr-east-06.cleardb.net'
	user: 'b86ea6769cf568'
	password: '773b2402'
	database: 'heroku_faa14f8802eb5e7'
	}

# ---------------------------------------------------------------------------

export openDB = () ->

	try
		db = mysql.createConnection(hConfig)
	catch err
		LOG "ERROR CONNECTING"
		LOG err.message
		process.exit()
	db.query = db.awaitQuery
	return db

# ---------------------------------------------------------------------------

export closeDB = (db) ->

	db.end()
	return
