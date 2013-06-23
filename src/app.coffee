###
1. every 5 minutes, scrape the homepage of every news site in our config
2. go through all the homepage facets

these should be keyed organization | timestamp and will be fetched on an
ongoing basis

---

3. one of those facets will isolate article links, for those
   you want to figure out which are *not* in the article database yet
   (get PK and see if it exists)
4. with those, go through all the article facets

these will probably only be fetched once (sometimes it makes sense to 
keep checking articles to see whether or not they change, but this
would be too intensive to be worth it, I think)
###

fs = require 'fs'
yaml = require 'js-yaml'
async = require 'async'
request = require 'request'
_ = require 'underscore'
#redis = require 'redis'
db = require './database'
utils = require './utils'
{retry, serialize} = utils
#redis = redis.createClient()

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

createTask = (facetName, facet, page) ->
    (callback) ->
        params = 
            uri: facet.endpoint
            body: page
            # qs: {url: page.url}
            json: yes

        request.post params, (err, response, result) ->
            item = {}
            item[facetName] = result
            _.extend page, item

            if err or response.statusCode isnt 200
                callback new retry.CouldNotFetch()
            else
                callback null, result

# page.type = 'homepage|article'

createTasks = (facets, page) ->
    page.timestamp = Math.ceil new Date().getTime() / 1000
    tasks = {}

    for facetName, facet of facets
        task = createTask facetName, facet, page
        dependencies = facet.dependencies or []
        tasks[facetName] = [dependencies..., task]

    tasks

annotateHomepage = (page, callback) ->
    tasks = createTasks facets.homepage, page

    async.auto tasks, (err, results) ->
        if err then return callback err
        page.scraper.links = page.scraper.links.join(' ')
        #console.log db.deflate page
        history.homepages.put page, _.once callback
        callback null

annotateHomepages = (pages, callback=utils.noop) ->
    async.each pages, annotateHomepage, callback

# TODO: put this in Redis instead
seen = []

getLinks = (homepages) ->
    ###
    TODO: figure out which links are *new*, don't just pass all of them off

    1. quick check in Redis
       EXISTS <page>
    2. set each new link in Redis, which we keep around for a day
       SET <page>
       EXPIRE <page> 86400
    3. pass off new links
    ###

    urls = _.flatten homepages.map (page) -> page.scraper.links.split ' '
    unseen = urls.filter (url) -> url not in seen
    links = unseen.map (url) -> {url}
    seen.push unseen...

    links

annotatePage = (page, callback) ->
    tasks = createTasks facets.article, page

    async.auto tasks, (err, results) ->
        if err then return callback err
        history.articles.put page, _.once callback
        callback null


annotatePages = (links, callback=utils.noop) ->
    async.each links, annotatePage, callback


homepages = _.values organizations

main = ->
    console.log '[running main]'
    annotateHomepages homepages, (err) ->
        links = getLinks homepages
        annotatePages links, (err) ->
            console.log '[ran full sweep]'

main()
setInterval main, 60 * 1000