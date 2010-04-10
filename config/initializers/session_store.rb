# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_aidwiki_session',
  :secret      => 'bb4f2044a8b9103728a878e6a96d172687108c2372ad03cfa95a6c5125d7dab52e95b97e2fdea6d5a23b88e4168f80617d353829b606116ad9c6026e4776cf94'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
