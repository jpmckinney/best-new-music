require 'rubygems'
require 'bundler/setup'

require 'carmen/demonyms'
require 'rspotify'
require 'rspotify/oauth'
require 'sequel'
require 'sinatra'
require 'sinatra/cookies'
require 'tilt/erb'

require_relative 'database'

use Rack::Session::Cookie, secret: ENV['SECRET_TOKEN']
use OmniAuth::Strategies::Spotify, ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_CLIENT_SECRET'], scope: 'user-library-modify user-library-read user-read-private'

helpers do
  # Returns a user or nil.
  #
  # @return [RSpotify::User,nil] a user or nil
  def current_user
    @current_user ||= if cookies[:auth]
      RSpotify::User.new(Marshal.load(cookies[:auth]))
    end
  end

  # Returns the demonym for the Spotify market.
  #
  # @return [String] the demonym for the Spotify market
  def demonym
    Carmen::Country.coded(ENV['SPOTIFY_MARKET']).demonym
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

post '/search' do
  begin
    content_type 'application/json'

    kind = params.fetch('kind', 'albums')
    year = Integer(params.fetch('year', Time.now.year))

    dataset = Album.where(kind: kind, year: year).exclude(spotify_id: nil).reverse_order(:created_at)

    albums = {}
    dataset.map(&:spotify_id).each_slice(20) do |slice|
      RSpotify::Album.find(slice).each do |album|
        albums[album.id] = album
      end
    end

    response = []

    dataset.each do |record|
      response << {
        spotify_id: record.spotify_id,
        display_name: record.display_name,
        saved: current_user.saved_tracks?(albums.fetch(record.spotify_id).tracks).all?,
      }

    end

    JSON.dump(response)
  rescue RestClient::BadRequest => e
    if JSON.parse(e.http_body)['error'] == 'invalid_client'
      redirect '/sign_out'
    else
      raise
    end
  end
end

post '/submit' do
  content_type 'application/json'

  logger.info(params)
  albums = RSpotify::Album.find(params[:spotify_id])

  if albums
    albums.each do |album|
      current_user.save_tracks!(album.tracks)
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
<div class="container">
  <h1>Save Pitchfork's Best New Music to your Spotify account.</h1>
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
          '<label><input type="checkbox" name="spotify_id[]" value="' + album.spotify_id + '"' + (album.saved === true ? ' checked disabled' : '') + '>' + album.display_name + '</label>' +
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
<p>Press the button to authorize this app to modify your Spotify library.</p>
<p><a href="/auth/spotify" class="btn btn-primary btn-lg">Log in with Spotify</a></p>
<p>This app is configured for the <strong><%= demonym %></strong> market. Try it, but if it doesn't work in your market, <a href="https://github.com/jpmckinney/best_new_music#readme">deploy your own app</a>.</p>
<p class="text-muted">This is the same as the "Log in with Google" or "Log in with Facebook" buttons that you see everywhere.</p>

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
      <% Time.now.year.downto(2015) do |year| %>
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
  <p class="text-danger"><strong>There is no undo.</strong></p>
  <p>This app is configured for the <strong><%= demonym %></strong> market. Try it, but if it doesn't work in your market, <a href="https://github.com/jpmckinney/best_new_music#readme">deploy your own app</a>.</p>
  <p class="text-muted">This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.</p>
</footer>
