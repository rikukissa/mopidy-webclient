Q      = require 'q'
$      = require 'jquery'
config = require '../../config.coffee'

module.exports =
  getAlbumArt: (artist, album) ->
    deferred = Q.defer()

    $.ajax(
      url: 'http://ws.audioscrobbler.com/2.0/'
      type: 'GET'
      data:
        method: 'album.getinfo'
        artist: artist
        album: album
        api_key: config.lastFM.apiKey
        format: 'json'
    ).done((data)->    
      return deferred.reject new Error('Album not found', data) unless data.album?
      unless data.album.image[data.album.image.length - 1]['#text']
        return deferred.reject new Error('Image not found')
      return deferred.resolve data.album.image[data.album.image.length - 1]['#text']
    ).fail -> deferred.reject new Error('XHR error')
    
    deferred.promise