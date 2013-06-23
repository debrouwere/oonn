fs = require 'fs'
yaml = require 'js-yaml'
async = require 'async'
request = require 'request'
_ = require 'underscore'
db = require './database'
{retry, serialize} = require './utils'
express = require 'express'

loadConfig = (name) ->
    filename = __dirname + "/config/#{name}.yml"
    yaml.load fs.readFileSync filename, 'utf8'

facets =
    article: loadConfig 'article'
    homepage: loadConfig 'homepage'

organizations = loadConfig 'organizations'

credentials = 
    accessKeyId: process.env.POLLSTER_AWS_ACCESS_KEY_ID
    secretAccessKey: process.env.POLLSTER_AWS_SECRET_ACCESS_KEY
    region: process.env.POLLSTER_AWS_REGION

dynamo = db.connect credentials
history = 
    homepages: db.interfaceFor dynamo, 'oonn-homepages'
    articles: db.interfaceFor dynamo, 'oonn-articles'

credentials = 
    accessKeyId: process.env.POLLSTER_AWS_ACCESS_KEY_ID
    secretAccessKey: process.env.POLLSTER_AWS_SECRET_ACCESS_KEY
    region: process.env.POLLSTER_AWS_REGION

app = express()

app.get '/homepages', (req, res) ->
    history.homepages.scan (err, list) ->
        res.send list

app.get '/articles', (req, res) ->
    history.articles.scan (err, list) ->
        res.send list

app.listen 3000