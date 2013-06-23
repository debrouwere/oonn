AWS = require 'aws-sdk'
async = require 'async'
_ = require 'underscore'
utils = require './utils'


exports.deflate = deflate = (structure) ->
    obj = utils.serialize.deflate structure

    description = {}
    for k, v of obj
        switch typeof v
            when 'number'
                description[k] = {N: v.toString()}
            when 'string'
                description[k] = {S: v}

    description

exports.inflate = inflate = (description) ->
    obj = {}
    for k, el of description
        for type, v of el
            switch type
                when 'N'
                    obj[k] = parseFloat v
                when 'S'
                    obj[k] = v

    utils.serialize.inflate obj


exports.connect = (location) ->
        AWS.config.update location
        client = new AWS.DynamoDB().client
        return client

exports.interfaceFor = (client, name, options={}) ->
    collection = 
        name: name
        client: client

        scan: (callback) ->
            q =
                TableName: name

            client.scan q, _.once (err, result) ->
                items = result.Items.map inflate
                callback err, items

        get: (key..., value, callback) ->
            if _.isEmpty key
                key = options.pk
            else
                key = key[0]

            q = 
                TableName: name
                Key: {}
            q.Key[key] = 
                'S': value

            client.getItem q, _.once (err, result) =>
                if err
                    callback err
                else
                    if 'Item' of result then item = inflate result.Item
                    callback null, item

        put: (item, callback) ->
            q = 
                TableName: name
                Item: (deflate item)
            client.putItem q, callback

        remove: (key..., value, callback) ->
            if _.isEmpty key
                key = options.pk
            else
                key = key[0]

            q = 
                TableName: name
                Key: {}
            q.Key[key] =
                'S': value

            client.deleteItem q, callback