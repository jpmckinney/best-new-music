DB = Sequel.connect(ENV.fetch('DATABASE_URL', 'postgres://localhost/best_new_music'))

Sequel::Model.plugin :timestamps

class Album < Sequel::Model
end
