## Pitchfork: Best New Music

Save [Pitchfork](http://pitchfork.com/)'s [Best New Music](http://pitchfork.com/reviews/best/albums/) to your [Spotify](https://www.spotify.com/) account.

* Create a [Spotify application](https://developer.spotify.com/my-applications/#!/applications)
* Add Redirect URIs to your Spotify application:
  * `http://localhost:9292/auth/spotify/callback`
  * The Heroku app's callback URL
* Remember to click "Save"

The application can either run locally or publicly.

You can edit [`config.ru`](https://github.com/jpmckinney/best_new_music/blob/master/config.ru#L35) to instead add [Best New Tracks](http://pitchfork.com/reviews/best/tracks/) or [Best New Reissues](http://pitchfork.com/reviews/best/reissues/), or to add previous year's albums.

The application log will `WARN` if any albums can't be found on Spotify.

```
heroku create
heroku config:set SPOTIFY_CLIENT_ID=3095ac09efb0341219c195851618e656
heroku config:set SPOTIFY_CLIENT_SECRET=fc044d1876f9792d264879ff18094eaa
heroku config:set SECRET_TOKEN=1c40ae179230d9680b45ce63e8a9e314977bf6b15ab65ef379491e69d69f68b9cfc875b2881f3c6fc39ca5b26f1eba03f933e8c7b03386f43e5a5e699af77c64036b26642537f0e126bfe406d1170639d165e7637285e82ec2fbb378c409060cb4d15200bf8360365431f82017bae12187d2ddad962b8a4511e9ed245384276c
git push heroku master
```

Copyright (c) 2015 James McKinney, released under the MIT license
