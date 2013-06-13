james  = require 'james'
jade   = require 'james-jade-static'
stylus = require 'james-stylus'
uglify = require 'james-uglify'

shim       = require 'browserify-shim'
browserify = require 'browserify'
coffeeify  = require 'coffeeify'

WebSocketServer = require('websocket').server
WebSocketClient = require('websocket').client
http = require('http')

copyFile = (file) -> james.read(file).write(file.replace('client/', 'public/'))

FILES_TO_COPY = [
  'client/**/*.css',
  'client/**/*.jpg',
  'client/**/*.png',
  'client/**/*.gif',
]

james.task 'copy_files', -> FILES_TO_COPY.forEach (glob) -> james.list(glob).forEach copyFile

liveReload = (port) ->
  server = http.createServer (request, response) ->
    response.writeHead 404
    response.end()

  server.listen port

  wsServer = new WebSocketServer(
    httpServer: server
    autoAcceptConnections: false
  )

  connections = []
  
  wsServer.on "request", (request) ->
    connection = request.accept(null, request.origin)
    connections.push connection
    connection.on "close", () ->
      connections.splice connections.indexOf(connection), 1

  reload = (refreshOnly = false) ->
    for connection in connections
      connection.sendUTF (if refreshOnly then 'refresh' else 'reload') 
    console.log 'Reload now!'

  return reload

reload = liveReload(9002)

transmogrifyCoffee = (debug) ->
  libs =
    jquery:
      path: './client/js/vendor/jquery-1.10.1.min.js'
      exports: '$'

  bundle = james.read shim(browserify(), libs)
    .transform(coffeeify)
    .require(require.resolve('./client/js/main.coffee'), entry: true)
    .bundle
      debug: debug

  bundle = bundle.transform(uglify) unless debug
  bundle.write('public/js/bundle.js').promise.then () -> reload()

james.task 'browserify', -> transmogrifyCoffee false
james.task 'browserify_debug', -> transmogrifyCoffee true


transmogrifyJade = (file) ->
  james.read(file)
    .transform(jade)
    .write(file
      .replace('client', 'public')
      .replace('.jade', '.html'))
    .promise.then -> reload()

james.task 'jade_static', ->
  james.list('client/**/*.jade').forEach transmogrifyJade

transmogrifyStylus = (file) ->
  james.read(file)
    .transform(stylus)
    .write(file
      .replace('client', 'public')
      .replace('.stylus', '.css')
      .replace('.styl', '.css'))
    .promise.then -> reload true

james.task 'stylus', ->
  james.list('client/**/*.styl').forEach transmogrifyStylus

james.task 'actual_watch', ->
  james.watch 'client/**/*.coffee', -> transmogrifyCoffee true
  james.watch 'client/**/*.jade', (ev, file) -> transmogrifyJade file
  james.watch 'client/**/*.styl', (ev, file) -> transmogrifyStylus file

  FILES_TO_COPY.forEach (glob) -> james.watch glob, (ev, file) -> copyFile file

james.task 'build_debug', ['browserify_debug', 'jade_static', 'stylus', 'copy_files']
james.task 'build', ['browserify', 'jade_static', 'stylus', 'copy_files']
james.task 'watch', ['build_debug', 'actual_watch', 'browserify']
james.task 'default', ['watch']

require('./server/server.coffee')