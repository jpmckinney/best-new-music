Sequel.migration do
  change do
    add_column :albums, :country_name, String
  end
end
