# Require Node.js core modules.
fs          = require 'fs'
url         = require 'url'
http        = require 'http'
querystring = require 'querystring'

#### The Pixel Ping server

# Keep the version number in sync with `package.json`.
VERSION = '0.1.2'

# The in-memory hit `store` is just a hash. We map unique identifiers to the
# number of hits they receive here, and flush the `store` every `interval`
# seconds.
store = {}

# Record a single incoming hit from the remote pixel.
record = (params) ->
  return unless key = params.query?.key
  store[key] or= 0
  store[key] +=  1

# Serializes the current `store` to JSON, and creates a fresh one. Add a
# `secret` token to the request object, if configured.
serialize = ->
  data  = json: JSON.stringify(store)
  data.secret = process.env.SECRET if process.env.SECRET
  querystring.stringify data

# Reset the `store`.
reset = ->
  store = {}

# Flushes the `store` to be saved by an external API. The contents of the store
# are sent to the configured `endpoint` URL via HTTP POST.
flush = ->
  log store
  data = serialize()
  endHeaders['Content-Length'] = data.length
  request = endpoint.request 'POST', endParams.pathname, endHeaders
  request.write data
  request.on 'response', (response) ->
    reset()
    console.info '--- flushed ---'
  request.end()

# Log the contents of the `store` to **stdout**. Happens on every flush, so that
# there's a record of hits if something goes awry.
log = (hash) ->
  for key, hits of hash
    console.log "#{hits}:\t#{key}"

# Create a `Server` object. When a request comes in, ensure that it's looking
# for `pixel.gif`. If it is, serve the pixel and record the request.
server = http.createServer (req, res) ->
  params = url.parse req.url, true
  if params.pathname is '/pixel.gif'
    res.writeHead 200, pixelHeaders
    res.end pixel
    record params
  else
    res.writeHead 404, emptyHeaders
    res.end ''
  null

#### Configuration

# Load the configuration and the contents of the tracking pixel. Handle requests
# for the version number, and usage information.
configPath  = process.argv[2]
if configPath in ['-v', '-version', '--version']
  console.log "Pixel Ping version #{VERSION}"
  process.exit 0

pixel       = fs.readFileSync __dirname + '/pixel.gif'

# HTTP headers for the pixel image.
pixelHeaders =
  'Cache-Control':        'private, no-cache, proxy-revalidate, max-age=0'
  'Content-Type':         'image/gif'
  'Content-Disposition':  'inline'
  'Content-Length':       pixel.length

# HTTP headers for the 404 response.
emptyHeaders =
  'Content-Type':   'text/html'
  'Content-Length': '0'

# If an `endpoint` has been configured, create an HTTP client connected to it,
# and log a warning otherwise.
console.info "Flushing hits to #{process.env.ENDPOINT}"
endParams = url.parse process.env.ENDPOINT
endpoint  = http.createClient endParams.port or 80, endParams.hostname
endpoint.on 'error', (e) ->
  reset() if process.env.DISCARD
  console.log "--- cannot connect to endpoint #{process.env.ENDPOINT}: #{e.message}"
endHeaders =
  'host':         endParams.host
  'Content-Type': 'application/x-www-form-urlencoded'

# Sending `SIGUSR1` to the Pixel Ping process will force a data flush.
process.on 'SIGUSR1', ->
  console.log 'Got SIGUSR1. Forcing a flush:'
  flush()

# Don't let exceptions kill the server.
process.on 'uncaughtException', (err) ->
  console.error "Uncaught Exception: #{err}"

#### Startup

# Start the server listening for pixel hits, and begin the periodic data flush.
server.listen process.env.PORT
setInterval flush, process.env.INTERVAL * 1000

console.log "Listening on port #{process.env.PORT}..."
