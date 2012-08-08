fs = require 'fs'

{print} = require 'util'
{spawn} = require 'child_process'

all = (callback) ->
  coffee = spawn 'coffee', ['-c', '-w', 'app.coffee', 'server.coffee', 'public/javascripts/client.coffee']
  coffee.stderr.on 'data', (data) ->
    process.stderr.write data.toString()
  coffee.stdout.on 'data', (data) ->
    print data.toString()
  coffee.on 'exit', (code) ->
    callback?() if code is 0

task 'all', 'Build all', ->
  all()