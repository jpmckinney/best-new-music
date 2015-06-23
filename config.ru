require 'rubygems'
require 'bundler/setup'

require 'faraday'
require 'nokogiri'
require 'sinatra'
require 'rspotify'
require 'rspotify/oauth'
require 'tilt/erb'

use Rack::Session::Cookie, secret: ENV['SECRET_TOKEN']
use OmniAuth::Strategies::Spotify, ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'], scope: 'playlist-modify-public user-library-modify user-read-private'

helpers do
  def playlist
    @playlist ||= begin
      # @todo Paginate if more than 50 playlists.
      # Q: "And searching for playlists within a user’s library?"
      # A: "No, it’s not possible. You would need to fetch the user’s playlists and go through them."
      # @see https://developer.spotify.com/web-api/search-item/

      name = "Pitchfork: Best New Music (#{kind.capitalize}, #{year})"
      playlist = user.playlists(limit: 50).find{|playlist| playlist.name == name}
      playlist = user.create_playlist!(name) if playlist.nil?
      playlist
    end
  end
end

get '/' do
  erb :index
end

get '/auth/spotify/callback' do
  kind = 'albums' # tracks, reissues
  year = Time.now.year

  user = RSpotify::User.new(request.env['omniauth.auth'])

  actual = nil
  page = 1

  begin
    url = "http://pitchfork.com/reviews/best/#{kind}/#{page}/"

    Nokogiri::HTML(Faraday.get(url).body).xpath('//ul[contains(@class,"bnm-list")]//div[@class="info"]').each do |div|
      artist_name = div.xpath('.//h1').text.downcase
      album_name = div.xpath('.//h2').text.sub(/ EP\z/, '').downcase
      actual = Integer(div.xpath('.//h4').text[/\b\d{4}\b/])

      if actual == year
        query = "#{artist_name} #{album_name}"

        albums = RSpotify::Album.search(query, market: {from: user})

        logger.info("#{albums.size} found for '#{query}'")
        albums.each do |album|
          logger.info("  #{album.artists[0].name} - #{album.name}")
        end

        # Reject mismatches.
        albums.reject! do |album|
          album.name.sub(/ EP\z/, '').downcase != album_name || album.artists[0].name.downcase != artist_name
        end

        # Reject non-explicit albums.
        if albums.any?{|album| album.tracks.any?(&:explicit)}
          albums.reject!{|album| album.tracks.none?(&:explicit)}
        end

        if albums.one?
          logger.info("  adding #{albums[0].artists[0].name} - #{albums[0].name}")
          user.save_tracks!(albums[0].tracks)
          # Spotify doesn't allow sorting playlists by album.
          # playlist.add_tracks!(albums[0].tracks)
        else
          logger.warn("#{albums.size} remaining")
          albums.each do |album|
            logger.info("  #{album.artists[0].name} - #{album.name}")
          end
        end
      else
        break
      end
    end

    page += 1
  end while actual == year

  erb :callback
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
<div class="container" style="margin-top: 5%; text-align: center;">
<%= yield %>
</div>
</div>
</body>
</html>

@@index
<p><a href="/auth/spotify" class="btn btn-primary btn-lg">Save Pitchfork's Best New Albums to Spotify</a></p>
<p class="text-danger">There is no undo.</p>
<p class="text-muted">This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.</p>

@@callback
<div class="alert alert-success">Success!</div>
