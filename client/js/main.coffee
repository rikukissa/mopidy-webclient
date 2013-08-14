Q         = require 'q'
$         = require 'jquery'
_         = require 'underscore'
ko        = require 'knockout'
url       = require 'url'
Snap      = require 'snap'
FastClick = require 'fastclick'

Player    = require './player.coffee'
utils     = require './utils.coffee'

player = new Player
  webSocketUrl: "ws://raspberrypi:6680/mopidy/ws/"

class ViewModel
  constructor: (@snapper) ->
    @currentTrack = ko.observable null
    @currentView  = ko.observable "now-playing"
    @currentTab   = ko.observable "artists"
    @albumArt     = ko.observable null
    @loading      = ko.observable true
    @state        = ko.observable 'stopped'
    @playlists       = ko.observableArray []
    @currentPlaylist = ko.observable null
    @currentAlbum    = ko.observable null
    @currentAlbums   = ko.observableArray []
    @currentArtist   = ko.observable null
    @currentTracks   = ko.observable null
    @queuedTracks    = ko.observableArray []
    
    @searchResults =
      artists: ko.observableArray []
      albums: ko.observableArray []
      tracks: ko.observableArray []
    
    @defaultAlbumArt = "../img/domo.jpg"
  
    @searchKeyword = ko.observable ''

  # View Changes

  setView: (viewName) => () =>
    @currentView viewName
    @snapper.close()
    @searchKeyword ''

  setTab: (tabName) => () =>
    @currentTab tabName

  enterPlayQueue: =>
    @load(player.tracklist.getTracks()
      .then (tracks) =>
        @queuedTracks tracks
        @setView('play-queue')()
        @setScrollPosition()
    )
  enterAlbumInfo: (album) =>
    @currentAlbum album
    player.library.search(album: album.name, artist: @currentArtist().name)
      .then ([fileSearch, searchResult]) =>
        @currentTracks searchResult.tracks
        @setView('album')()

  enterArtistInfo: (artist) =>
    @currentArtist artist
    player.library.search(artist: artist.name)
      .then ([fileSearch, searchResult]) =>
        @currentAlbums searchResult.albums
        @setView('artist')()
  
  enterArtistAlbumInfo: (album) =>
    @currentArtist album.artists[0]
    @enterAlbumInfo.apply this, arguments
  
  setScrollPosition: =>
    $currentTrack = $('#play-queue .current-track')
    return unless $currentTrack.length > 0
    $('#play-queue .playlist-tracks')
      .scrollTop $currentTrack.offset().top - $currentTrack.height() * 2
  
  setTrack: (track) ->
    @currentTrack track
    return unless track?
    utils.getAlbumArt(track.artists[0].name, track.album.name)
      .then (imageUrl) =>
        @albumArt imageUrl
      , =>
        @albumArt null
  
  setTrackIndex: (index = 0)->
    player.tracklist.getTracks()
      .then (tracks) =>
        @setTrack tracks[index] if tracks[index]?

  filterData: (data) =>
    return _.filter data, (item) =>
      regex = new RegExp(@searchKeyword(), 'i')
      return true if regex.test item.name

      return false if not item.artists? or item.artists.length == 0
      for artist in item.artists
        return true if regex.test artist.name
      
      false

  setSearchKeyword: (obj, event) =>
    @searchKeyword $(event.target).val()

  toggleSidebar: =>
    if @snapper.state().state is "left"
      @snapper.close()
    else
      @snapper.open 'left'

  openPlaylist: (playlist) =>
    @currentPlaylist playlist
    @setView("playlist")()
  
  togglePlayState: ->
    return @load player.playback.pause() if @state() == "playing"
    if @state() == "paused" || @state() == "stopped"
      @load player.playback.play()
      
  setState: (state) ->
    @state state

  playTrack: (track) =>
    if @currentTrack()?
      return @load(player.playback.getCurrentTlTrack()
        .then (tlTrack) ->
          player.tracklist.index(tlTrack)
        .then (index) ->
          player.tracklist.add([track], index + 1)
        .then (tlTracks) ->
          player.playback.play(tlTracks[0])
      )
    @load(player.tracklist.add([track])
      .then (tlTracks) ->
        player.playback.play(tlTracks[0])
    )
  load: (promise) ->
    deferred = Q.defer()
    @loading true
    promise.then =>
      @loading false
      deferred.resolve.apply this, arguments
    deferred.promise

  playNext: ->  
    @load player.playback.next()

  playPrevious: ->
    @load player.playback.previous()

  getAlbumBackground: ->
    return "url(#{@defaultAlbumArt})" unless @albumArt()?
    return "url(#{@albumArt()})"

  isCurrentTrack: (track) =>
    if @currentTrack()? then @currentTrack().uri == track.uri else false

  submitSearch: (viewModel, event) ->
    player.library.search(any: $(event.target).val())
      .then ([fileSearch, searchResult]) =>
        @searchResults.artists searchResult.artists
        @searchResults.albums searchResult.albums
        @searchResults.tracks searchResult.tracks

$ ->
  snapper = new Snap
    element: document.getElementById 'main'
    disable: 'right'
  
  viewModel = new ViewModel snapper

  player.on 'event:trackPlaybackStarted', (data) ->
    viewModel.setTrack data.tl_track.track
  
  player.on 'event:playbackStateChanged', (data) ->
    viewModel.state data.new_state

  viewModel.load(player.initialize()
    .then ([state, playlists, currentTrack]) ->
      viewModel.setState state
      viewModel.playlists playlists
      viewModel.setTrack currentTrack
  ).fail ->
    console.log arguments
    
  FastClick document.body

  ko.applyBindings viewModel
