require 'rubygems'
require 'bundler/setup'

require 'json'
require 'open-uri'

require 'musicbrainz'
require 'rspotify'
require 'sequel'

require_relative 'database'

MusicBrainz.configure do |c|
  c.app_name = 'best-new-albums'
  c.app_version = '1.0'
  c.contact = 'james@slashpoundbang.com'
end

task :setup do
  DB.create_table :albums do
    primary_key :id
    String :kind
    Integer :year
    String :artist_name
    String :album_name
    String :spotify_id, index: true
    String :display_name
    String :country_name
    String :log
    DateTime :created_at, index: true

    index [:kind, :year, :artist_name, :album_name]
  end
end

task :pitchfork do
  year = Time.now.year
  per_page = 50

  {
    'albums' => 'bnm',
    'reissues' => 'bnr',
  }.each do |kind,parameter|
    last = Album.where(kind: kind).reverse_order(:created_at).first

    offset = 0

    loop do
      url = "http://pitchfork.com/api/v1/albumreviews/?limit=#{per_page}&offset=#{offset}&#{parameter}=1"

      JSON.load(open(url).read)['results'].each do |result|
        album = result['tombstone']['albums'][0]

        if album['labels_and_years'][0]['year'] != year
          # Don't go beyond the present year.
          exit
        end

        artist_name = album['album']['artists'][0]['display_name']
        album_name = album['album']['display_name']

        attributes = {
          kind: kind,
          year: year,
          artist_name: artist_name,
          album_name: album_name,
        }

        if Album.where(attributes).any?
          # No more new albums.
          exit
        else
          puts JSON.pretty_generate(attributes)
          Album.create(attributes)
        end
      end

      offset += per_page
    end
  end
end

task :spotify do
  # Returns the album as a string.
  #
  # @param [RSpotify::Album] an album
  # @return [String] the album as a string
  def display_name(album)
    "#{album.artists[0].name} - #{album.name}#{album.tracks.any?(&:explicit) ? ' [Explicit]' : ''}"
  end

  def clean_album_name(name)
    name.downcase.
      # Normalize apostrophes.
      gsub('’', "'").
      # Remove trailing "EP".
      sub(/ ep\z/, '').
      # Remove trailing periods.
      sub(/\.+\z/, '').
      # Remove periods, e.g. "Sept. 5th".
      gsub(/\.+/, '').
      # Remove versions and editions.
      sub(/ \((?:deluxe|(?:deluxe|special) edition)\)/i, '')
  end

  def clean_artist_name(name)
    name.downcase.
      # Remove periods, e.g. "Anderson .Paak".
      gsub(/\.+/, '').
      # Remove versions and editions.
      sub(/ \((?:(?:deluxe|special) edition)\)/i, '')
  end

  Album.where(spotify_id: nil).reverse_order(:created_at).each do |record|
    log = []

    default_display_name = "#{record.artist_name} - #{record.album_name}"
    query = "#{record.artist_name.downcase} #{clean_album_name(record.album_name)}"

    # The Spotify API is too slow to query in a web request, so we can't pass `market: {from: current_user}`.
    albums = RSpotify::Album.search(query, market: ENV['SPOTIFY_MARKET'])

    # Log the search.
    log << "Searching Spotify for #{default_display_name} with keywords '#{query}'..."
    messages = albums.map do |album|
      display_name(album)
    end

    # Reject mismatches.
    clean_pitchfork_album_name = clean_album_name(record.album_name)
    clean_pitchfork_artist_name = clean_artist_name(record.artist_name)
    albums.reject! do |album|
      clean_album_name(album.name) != clean_pitchfork_album_name || clean_artist_name(album.artists[0].name) != clean_pitchfork_artist_name
    end

    # Reject non-explicit albums.
    if albums.any?{|album| album.tracks.any?(&:explicit)}
      albums.reject!{|album| album.tracks.none?(&:explicit)}
    end

    # Reject non-deluxe albums.
    if albums.any?{|album| album.name['(Deluxe Edition)']}
      albums.reject!{|album| !album.name['(Deluxe Edition)']}
    end

    # Prepare the attributes.
    if albums.one?
      spotify_id = albums[0].id
      display_name = display_name(albums[0])
    else
      spotify_id = nil
      display_name = default_display_name
    end

    # Log the matches.
    if messages.one?
      log = []
    elsif messages.none?
      log[0] += ' No results found'
    else
      log[0] += ' Found:'
      messages.each do |message|
        log << "#{albums.any?{|album| message == display_name(album)} ? '✓' : ' '} #{message}"
      end
    end

    if log.any?
      # Debugging.
      puts log
      puts
    end

    record.update({
      spotify_id: spotify_id,
      display_name: display_name,
      log: log.join("\n"),
    })
  end
end

task :country do
  Album.where(country_name: nil).reverse_order(:created_at).each do |record|
    artist = MusicBrainz::Artist.find_by_name(record.artist_name)
    if artist
      record.update(country_name: artist.country)
    else
      puts "Not found: #{record.artist_name}"
    end
    print '.'
  end
end
