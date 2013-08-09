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

mopidy = new Mopidy()

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
    @load(mopidy.tracklist.getTracks()
      .then (tracks) =>
        @queuedTracks tracks
        @setView('play-queue')()
        @setScrollPosition()
    )
  enterAlbumInfo: (album) =>
    @currentAlbum album
    mopidy.library.search(album: album.name, artist: @currentArtist().name)
      .then ([fileSearch, searchResult]) =>
        @currentTracks searchResult.tracks
        @setView('album')()

  enterArtistInfo: (artist) =>
    @currentArtist artist
    mopidy.library.search(artist: artist.name)
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

    getAlbumArt(track.artists[0].name, track.album.name).then (imageUrl) =>
      @albumArt imageUrl
    , =>
      @albumArt null
  
  setTrackIndex: (index = 0)->
    mopidy.tracklist.getTracks()
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
    return @load mopidy.playback.pause() if @state() == "playing"
    if @state() == "paused" || @state() == "stopped"
      @load mopidy.playback.play()
      
  setState: (state) ->
    @state state

  playTrack: (track) =>
    if @currentTrack()?
      return @load(mopidy.playback.getCurrentTlTrack()
        .then (tlTrack) ->
          mopidy.tracklist.index(tlTrack)
        .then (index) ->
          mopidy.tracklist.add([track], index + 1)
        .then (tlTracks) ->
          mopidy.playback.play(tlTracks[0])
      )
    @load(mopidy.tracklist.add([track])
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
    if @currentTrack()? then @currentTrack().uri == track.uri else false

  submitSearch: (viewModel, event) ->
    mopidy.library.search(any: $(event.target).val())
      .then ([fileSearch, searchResult]) =>
        @searchResults.artists searchResult.artists
        @searchResults.albums searchResult.albums
        @searchResults.tracks searchResult.tracks

  createPlayQueue: (playlists) ->
    mopidy.tracklist.add playlists[0].tracks

$ ->
  snapper = new Snap
    element: document.getElementById 'main'
    disable: 'right'
  
  viewModel = new ViewModel snapper

  #mopidy.on(console.log.bind(console))
  mopidy.on 'event:trackPlaybackStarted', (data) ->
    viewModel.setTrack data.tl_track.track
  mopidy.on 'event:playbackStateChanged', (data) ->
    viewModel.state data.new_state

  mopidy.on 'state:online', ->
    viewModel.load(mopidy.playback.getState()
      .then (state)->
        viewModel.setState state
        mopidy.playlists.getPlaylists()
      .then (playlists) ->
        viewModel.playlists playlists
        mopidy.tracklist.getLength()
        .then (trackListLength) -> 
          if trackListLength is 0 && playlists.length > 0
            return viewModel.createPlayQueue(playlists)
              .then ->
                mopidy.playback.getCurrentTrack()
          mopidy.playback.getCurrentTrack()
      .then (track) ->  
        return viewModel.setTrack track if track?
        viewModel.setTrackIndex 0
    )

  FastClick document.body
  ko.applyBindings viewModel
