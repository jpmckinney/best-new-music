require 'rubygems'
require 'bundler/setup'

require 'fiber'

require 'faraday'
require 'nokogiri'
require 'rspotify'
require 'rspotify/oauth'
require 'sinatra'
require 'sinatra/cookies'
require 'tilt/erb'

use Rack::Session::Cookie, secret: ENV['SECRET_TOKEN']
use OmniAuth::Strategies::Spotify, ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'], scope: 'user-library-modify user-library-read user-read-private' # playlist-modify-public

class Album
  attr_reader :artist, :name, :log
  attr_accessor :id, :display_name, :saved

  # Initializes an album.
  #
  # @param [String] artist an artist's name
  # @param [String] name the album's name
  def initialize(artist, name)
    @artist = artist
    @name = name
    @log = []
  end

  # Returns the album as a hash
  #
  # @return [Hash] the album as a hash
  def to_h
    {
      id: id,
      name: display_name,
      saved: saved,
      log: log.join("\n"),
    }
  end
end

helpers do
  # Returns a user or nil.
  #
  # @return [RSpotify::User,nil] a user or nil
  def current_user
    @current_user ||= if cookies[:auth]
      RSpotify::User.new(Marshal.load(cookies[:auth]))
    end
  end

  # Returns the album as a string.
  #
  # @param [RSpotify::Album] an album
  # @return [String] the album as a string
  def display_name(album)
    "#{album.artists[0].name} - #{album.name}#{album.tracks.any?(&:explicit) ? ' [Explicit]' : ''}"
  end

  # Returns a list of artist and album names.
  #
  # @param [String] kind "albums" or "reissues"
  # @param [Integer] year a year
  # @return [Array] a list of artist and album names
  def best_new_music(kind, year)
    actual = nil
    page = 1

    Fiber.new do
      begin
        url = "http://pitchfork.com/reviews/best/#{kind}/#{page}/"

        Nokogiri::HTML(Faraday.get(url).body).xpath('//ul[contains(@class,"bnm-list")]//div[@class="info"]').each do |div|
          actual = Integer(div.xpath('.//h4').text[/\b\d{4}\b/])
          break unless actual == year

          artist_name = div.xpath('.//h1').text.downcase
          album_name = div.xpath('.//h2').text.sub(/ EP\z/, '').downcase

          Fiber.yield(Album.new(artist_name, album_name))
        end

        page += 1
      end while actual == year
    end
  end

  # @note Not used, since Spotify doesn't allow sorting playlists by album.
  def playlist
    @playlist ||= begin
      # Q: "And searching for playlists within a user’s library?"
      # A: "No, it’s not possible. You would need to fetch the user’s playlists and go through them."
      # @see https://developer.spotify.com/web-api/search-item/
      # @note Paginate if more than 50 playlists.

      name = "Pitchfork: Best New Music (#{kind.capitalize}, #{year})"
      playlist = current_user.playlists(limit: 50).find{|playlist| playlist.name == name}
      playlist = current_user.create_playlist!(name) if playlist.nil?
      playlist
    end
  end
end

get '/' do
  if current_user
    erb :index
  else
    erb :sign_in
  end
end

get '/sign_out' do
  cookies.delete(:auth)
  redirect to('/')
end

get '/auth/spotify/callback' do
  cookies[:auth] = Marshal.dump(request.env['omniauth.auth'])
  redirect to('/')
end

# @note Store Spotify IDs.
post '/search' do
  content_type 'application/json'

  kind = params.fetch('kind', 'albums')
  year = Integer(params.fetch('year', Time.now.year))
  fiber = best_new_music(kind, year)
  response = []

  while fiber.alive?
    record = fiber.resume

    if record
      query = "#{record.artist} #{record.name}"

      albums = RSpotify::Album.search(query, market: {from: current_user})

      # Log the matches.
      record.log << "'#{query}'"
      messages = albums.map do |album|
        display_name(album)
      end

      # Reject mismatches.
      albums.reject! do |album|
        album.name.sub(/ EP\z/, '').downcase != record.name || album.artists[0].name.downcase != record.artist
      end

      # Reject non-explicit albums.
      if albums.any?{|album| album.tracks.any?(&:explicit)}
        albums.reject!{|album| album.tracks.none?(&:explicit)}
      end

      if albums.one?
        record.id = albums[0].id
        record.display_name = display_name(albums[0])
        record.saved = current_user.saved_tracks?(albums[0].tracks).all?
      else
        record.display_name = query
      end

      messages.each do |message|
        record.log << "#{albums.any?{|album| message == display_name(album)} ? '+' : '-'} #{message}"
      end

      response << record.to_h
    end
  end

  JSON.dump(response)
end

post '/submit' do
  content_type 'application/json'

  logger.info(params)
  albums = RSpotify::Album.find(params[:id])

  if albums
    albums.each do |album|
      current_user.save_tracks!(album.tracks)
      # Spotify doesn't allow sorting playlists by album.
      # playlist.add_tracks!(album.tracks)
    end
  end

  JSON.dump(true)
end

run Sinatra::Application

__END__
@@layout
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="x-ua-compatible" content="ie=edge">
<title>Best New Music</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
</head>
<body>
<div class="container" style="margin-top: 40px">
<%= yield %>
</div>
<script src="https://code.jquery.com/jquery-2.1.4.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
<script>
$(function () {
  function ajax(selector, success) {
    var form = $(selector);

    form.submit(function (event) {
      var data = form.serializeArray();

      var elements = $(this).find('button:not([disabled]),input:not([disabled]),select:not([disabled])');
      elements.prop('disabled', true);

      $.post(form.attr('action'), data, function (data) {
        success(data);
        elements.prop('disabled', false);
      });

      event.preventDefault();
    });
  }

  ajax('#search', function (data) {
    var albums = $('#albums');
    albums.empty();

    $.each(data, function (i, album) {
      albums.append(
        '<div class="checkbox">' +
          '<label><input type="checkbox" name="id[]" value="' + album.id + '"' + (album.saved === true ? ' checked disabled' : (album.saved === null ? ' disabled' : '')) + '>' + album.name + '</label>' +
          '<span class="info" aria-label="Info" data-trigger="click hover" data-html="true" data-content="<pre>' + album.log + '</pre>">' + 
            ' <span class="glyphicon glyphicon-info-sign" aria-hidden="true"></span>' +
          '</span>' +
        '</div>'
      );
    });

    $('.info').popover();
    $('#submit').removeClass('hide');
  });

  ajax('#submit', function (data) {});
});
</script>
</body>
</html>

@@sign_in
<p><a href="/auth/spotify" class="btn btn-primary btn-lg">Sign in with Spotify</a></p>

@@index
<form accept-charset="UTF-8" action="/search" method="post" class="form-inline" id="search">
  <div class="form-group">
    Best New
    <select id="kind" name="kind" class="form-control">
      <option value="albums">Albums</option>
      <option value="reissues">Reissues</option>
    </select>
  </div>
  <div class="form-group">
    from
    <select id="year" name="year" class="form-control">
      <% Time.now.year.downto(Time.now.year) do |year| %>
        <option value="<%= year %>"><%= year %></option>
      <% end %>
    </select>
  </div>
  <button type="submit" class="btn btn-primary">Search</button>
  <span class="text-muted">(this may take a minute)</span>
</form>

<form accept-charset="UTF-8" action="/submit" method="post" class="hide" id="submit">
  <div id="albums"></div>
  <button type="submit" class="btn btn-primary">Save</button>
</form>

<footer style="margin-top: 40px">
  <p class="text-danger">There is no undo.</p>
  <p class="text-muted">This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.</p>
</footer>
