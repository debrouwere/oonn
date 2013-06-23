request = require 'request'
cheerio = require 'cheerio'
express = require 'express'
app = express()
app.use express.bodyParser()

app.post '/homepage', (req, res) ->
    body = req.body
    url = body.url
    console.log body, body.url

    request.get url, (err, response, html) ->
        $ = cheerio.load html
        href = $('a[href]').map -> $(this).attr 'href'
        console.log href
        res.send {
            links: href
            #html: html
        }

app.post '/article', (req, res) ->
    body = req.body
    url = body.url
    res.send {wordcount: 33}

app.post '/doubler', (req, res) ->
    body = req.body
    url = body.url
    console.log body
    res.send {wordcount2: body.wordcount.wordcount * 2}

app.listen 5000