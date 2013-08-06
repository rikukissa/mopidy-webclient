Q         = require 'q'
$         = require 'jquery'
_         = require 'underscore'
ko        = require 'knockout'
url       = require 'url'
Snap      = require 'snap'
FastClick = require 'fastclick'

lastFMAPIKey = '9c7fbd7c48b7b59a77d99b987ca3a163'

getAlbumArt = (artist, album) ->
  deferred = Q.defer()

  $.ajax(
    url: 'http://ws.audioscrobbler.com/2.0/'
    type: 'GET'
    data:
      method: 'album.getinfo'
      artist: artist
      album: album
      api_key: lastFMAPIKey
      format: 'json'
  ).done((data)->    
    return deferred.reject new Error('Album not found', data) unless data.album?
    unless data.album.image[data.album.image.length - 1]['#text']
      return deferred.reject new Error('Image not found')
    return deferred.resolve data.album.image[data.album.image.length - 1]['#text']
  ).fail -> deferred.reject new Error('XHR error')
  deferred.promise

mopidy = new Mopidy
  webSocketUrl: "ws://musicbox.local:6680/mopidy/ws/"

class ViewModel
  constructor: (@snapper) ->
    @currentTrack = ko.observable null
    @currentView  = ko.observable "now-playing"
    @albumArt     = ko.observable null
    @loading      = ko.observable true
    
    @playlists       = ko.observableArray []
    @currentPlaylist = ko.observable null
    @queuedTracks    = ko.observableArray []

    @defaultAlbumArt = "../img/domo.jpg"
  
  # View Changes

  setView: (viewName) => () ->
    @currentView viewName
    @snapper.close()

  enterPlayQueue: =>
    @load(mopidy.tracklist.getTracks()
      .then (tracks) =>
        @queuedTracks tracks
        @currentView 'play-queue'
        @snapper.close()
        @setScrollPosition()
    )

  setScrollPosition: =>
    $currentTrack = $('#play-queue .current-track')
    return unless $currentTrack.length > 0
    $('#play-queue .playlist-tracks')
      .scrollTop $currentTrack.offset().top - $currentTrack.height() * 2
  setTrack: (track) ->
    @currentTrack track

    getAlbumArt(track.artists[0].name, track.album.name).then (imageUrl) =>
      @albumArt imageUrl
    , =>
      @albumArt null
  
  toggleSidebar: =>
    if @snapper.state().state is "left"
      @snapper.close()
    else
      @snapper.open 'left'

  openPlaylist: (playlist) =>
    @currentPlaylist playlist
    @currentView "playlist"
  
  playTrack: (track) =>
    
    @load(mopidy.playback.getCurrentTlTrack() # Get current track
      .then (tlTrack) -> # Get the index of the current track
        mopidy.tracklist.index(tlTrack)
      .then (index) ->
        mopidy.tracklist.add([track], index + 1)
      .then (tlTracks) ->
        mopidy.playback.play(tlTracks[0])
    )

  load: (promise) ->
    deferred = Q.defer()
    @loading true
    promise.then =>
      @loading false
      deferred.resolve.apply this, arguments
    deferred.promise

  playNext: ->  
    @load mopidy.playback.next()

  playPrevious: ->
    @load mopidy.playback.previous()

  getAlbumBackground: ->
    return "url(#{@defaultAlbumArt})" unless @albumArt()?
    return "url(#{@albumArt()})"

  isCurrentTrack: (track) =>
    @currentTrack().uri == track.uri
$ ->
  snapper = new Snap
    element: document.getElementById 'main'
    disable: 'right'
  
  viewModel = new ViewModel snapper

  mopidy.on 'event:trackPlaybackStarted', (data) ->
    viewModel.setTrack data.tl_track.track

  mopidy.on 'state:online', ->
    viewModel.load(mopidy.playback.getCurrentTrack()).then (track) ->
      viewModel.setTrack track
    
    viewModel.load(mopidy.playlists.getPlaylists())
      .then (playlists) -> 
        viewModel.playlists playlists


  FastClick document.body


  ko.applyBindings viewModel
