require 'gibberish'

module Crypt

  ENCRYPTION_KEY = ENV['ENCRYPTION_KEY'] || 'bMjEAvZnfZy3ZvuiFXPvWPLEkPM3VB'

  extend self
  
  def encrypt(token)
    cipher = Gibberish::AES.new(ENCRYPTION_KEY)
    cipher.encrypt(token)
  end

  def decrypt(encrypted_token)
    cipher = Gibberish::AES.new(ENCRYPTION_KEY)
    cipher.decrypt(encrypted_token)
  end
  
end
