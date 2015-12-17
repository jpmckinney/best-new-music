## Pitchfork: Best New Music

Saves [Pitchfork](http://pitchfork.com/)'s [Best New Music](http://pitchfork.com/reviews/best/albums/) to your [Spotify](https://www.spotify.com/) account.

To deploy your own app, you need to know a little about programming and Heroku.

## Setup Spotify

1. Create a [Spotify application](https://developer.spotify.com/my-applications/#!/applications)
1. Add these Redirect URIs to your Spotify application:
  * `http://localhost:9292/auth/spotify/callback`
  * The Heroku app's callback URL, e.g. `https://myapp.herokuapp.com/auth/spotify/callback`
1. Remember to click "Save"

## Getting Started

Replace the example values of `SPOTIFY_MARKET`, `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` and `SECRET_TOKEN`.

    bundle
    createdb best_new_music
    rake setup
    rake pitchfork
    export SPOTIFY_MARKET=CA
    export SPOTIFY_CLIENT_ID=3095ac09efb0341219c195851618e656
    export SPOTIFY_CLIENT_SECRET=fc044d1876f9792d264879ff18094eaa
    export SECRET_TOKEN=1c40ae179230d9680b45ce63e8a9e314977bf6b15ab65ef379491e69d69f68b9cfc875b2881f3c6fc39ca5b26f1eba03f933e8c7b03386f43e5a5e699af77c64036b26642537f0e126bfe406d1170639d165e7637285e82ec2fbb378c409060cb4d15200bf8360365431f82017bae12187d2ddad962b8a4511e9ed245384276c
    rake spotify
    rackup

## Deployment

Replace the example values of `SPOTIFY_MARKET`, `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` and `SECRET_TOKEN`.

    heroku apps:create
    heroku config:set SPOTIFY_MARKET=CA
    heroku config:set SPOTIFY_CLIENT_ID=3095ac09efb0341219c195851618e656
    heroku config:set SPOTIFY_CLIENT_SECRET=fc044d1876f9792d264879ff18094eaa
    heroku config:set SECRET_TOKEN=1c40ae179230d9680b45ce63e8a9e314977bf6b15ab65ef379491e69d69f68b9cfc875b2881f3c6fc39ca5b26f1eba03f933e8c7b03386f43e5a5e699af77c64036b26642537f0e126bfe406d1170639d165e7637285e82ec2fbb378c409060cb4d15200bf8360365431f82017bae12187d2ddad962b8a4511e9ed245384276c
    git push heroku master
    heroku addons:create heroku-postgresql:hobby-dev
    heroku run rake setup
    heroku run rake pitchfork
    heroku run rake spotify
    heroku open

Add `rake pitchfork && rake spotify` to the Heroku Scheduler.

Copyright (c) 2015 James McKinney, released under the MIT license
