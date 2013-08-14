Q = require 'q'

class Player extends Mopidy
  constructor: ->
    super
    @currentState = 'stopped'
    @currentTrack = null
    @playlists = []

  getState: ->
    @playback.getState().then (state) =>
      @currentState = state

  getPlaylists: ->
    @playlists.getPlaylists().then (playlists) =>
      @playlists = playlists


  getCurrentTrack: ->
    @playback.getCurrentTrack().then (track) =>
      @currentTrack = track

  initializeQueue: ->
    @tracklist.getLength()
      .then (tracklistLength) ->
        if tracklistLength is 0 and @playlists.length > 0
          return @tracklist.add @playlists[0].tracks

  initialize: ->
    deferred = Q.defer()
    
    @on 'state:online', =>
      @initializeQueue()
        .then =>
          Q.all([
            @getState()
            @getPlaylists()
            @getCurrentTrack()
          ])  
        .then deferred.resolve

    return deferred.promise

module.exports = Player