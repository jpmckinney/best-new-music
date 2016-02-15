require 'rubygems'
require 'bundler/setup'

require 'json'

require 'faraday'
require 'nokogiri'
require 'rspotify'
require 'sequel'

require_relative 'database'

task :setup do
  DB.create_table :albums do
    primary_key :id
    String :kind
    Integer :year
    String :artist_name
    String :album_name
    String :spotify_id, index: true
    String :display_name
    String :log
    DateTime :created_at, index: true

    index [:kind, :year, :artist_name, :album_name]
  end
end

task :pitchfork do
  year = Time.now.year

  %w(albums reissues).each do |kind|
    last = Album.where(kind: kind).reverse_order(:created_at).first

    page = 1

    loop do
      url = "http://pitchfork.com/reviews/best/#{kind}/#{page}/"

      Nokogiri::HTML(Faraday.get(url).body).xpath('//ul[contains(@class,"bnm-list")]//div[@class="info"]').each do |div|
        if Integer(div.xpath('.//h4').text[/\b\d{4}\b/]) != year
          # Don't go beyond the present year.
          exit
        end

        artist_name = div.xpath('.//h1').text
        album_name = div.xpath('.//h2').text

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

      page += 1
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
      # Remove periods, e.g. "Anderson .Paak".
      gsub(/\./, '').
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
    albums.reject! do |album|
      clean_album_name(album.name) != clean_album_name(record.album_name) || album.artists[0].name.downcase != record.artist_name.downcase
    end

    # Reject non-explicit albums.
    if albums.any?{|album| album.tracks.any?(&:explicit)}
      albums.reject!{|album| album.tracks.none?(&:explicit)}
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
