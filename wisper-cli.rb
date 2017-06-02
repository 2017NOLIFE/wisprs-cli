require 'thor'
require 'http'
require 'httparty'
require 'gpgme'
require 'json'

# wispr cli class
class WisprCLI < Thor
  include GPGME
  include HTTParty
  base_uri  'localhost:3000/api/v1/'

  desc 'login', 'login to wispr'
  def login
    username = ask 'Enter your username:'
    password = ask 'Enter your password:'
    # say("connecting to #{self.class.base_uri}/accounts/authenticate", :green)
    say("logging in, please wait a moment!", :green)
    response = HTTP.post("#{self.class.base_uri}/accounts/authenticate",
                         json: { username: username, password: password })
    #say("#{response}")
    token=response.parse
    say("#{token["auth_token"]}")
    # say("#{response.auth_token}")
  end

  desc 'messages', 'list messages'
  def messages
  end

  desc 'getmessage', 'gets your message and tries to decrypts it'
  def getmessage
    # function to ask for keyfile password
    def passfunc(obj, uid_hint, passphrase_info, prev_was_bad, fd)
      io = IO.for_fd(fd, 'w')
      io.puts "PASSPHRASE"
      io.flush
    end

    encrypted_data = GPGME::Data.new(File.open("encrypted.txt.pgp"))
    key = GPGME::Data.new(File.open("key.txt"))

    ctx = GPGME::Ctx.new :passphrase_callback => method(:passfunc)
    ctx.import_keys key

    decrypted = ctx.decrypt encrypted_data
    decrypted.seek(0)
  end

  desc 'pk', 'set path for your private key'
  def pk
    path = ask 'Enter path to your private key:'
    say('thanks! path set, you will still need your password to access the key')
  end
end

WisprCLI.start(ARGV)
