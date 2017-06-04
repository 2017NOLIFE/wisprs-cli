require 'thor'
require 'http'
require 'httparty'
require 'gpgme'
require 'json'
require 'yaml'

# wispr cli class
class WisprCLI < Thor
  include GPGME
  include HTTParty
  $settings_file = YAML::load_file "./settings/settings.yml"
  $auth_file = YAML::load_file "./settings/token.yml"
  base_uri  'localhost:3000/api/v1/'
########################################
  desc 'login', 'login to wispr'
  def login
    username = ask 'Enter your username:'
    password = ask 'Enter your password:'
    # say("connecting to #{self.class.base_uri}/accounts/authenticate", :green)
    say("logging in, please wait a moment!", :green)
    response = HTTP.post("#{self.class.base_uri}/accounts/authenticate",
                         json: { username: username, password: password })
    token=response.parse

    $auth_file = token.to_yaml
    File.write("./settings/token.yml",$auth_file)
    say("#{token.to_yaml}")
  end
=begin
############################################
  desc 'messages', 'list messages'
  def messages
    def extract_messages(messages)
      messages['data'].map do |msg|
        { id: msg['id'],
          title: msg['attributes']['title'],
          about: msg['attributes']['about'],
          #status: msg['attributes']['status'],
          expire_date: msg['attributes']['expire_date'],
          body: msg['attributes']['body']}
          #from_user: msg['relationships']['from']['username'],
          #to_user: msg['relationships']['to']['username'] }
      end
    end

    currentid = $auth_file["account"]["id"]
    say("sending req to #{self.class.base_uri}/accounts/#{currentid}/messages")

    response = HTTP.auth("Bearer #{$auth_file["auth_token"]}")
                    .get("#{self.class.base_uri}/accounts/#{currentid}/messages")
    say(response.code)
    say(response)
    response.code == 200 ? extract_messages(response.parse) : nil

    #say($auth_file["auth_token"].to_json)

  end
=end
#######################################
  desc 'getmessage', 'gets message with id and decrypts it using keyfile'
  def getmessage(messageid)
    # function to ask for keyfile password
    def passfunc(obj, uid_hint, passphrase_info, prev_was_bad, fd)
      io = IO.for_fd(fd, 'w')
      io.puts "PASSPHRASE"
      io.flush
    end

    currentid = $auth_file["account"]["id"]
    #say("sending req to #{self.class.base_uri}/messages/#{messageid}")
    response = HTTP.auth("Bearer #{$auth_file["auth_token"]}")
                    .get("#{self.class.base_uri}/messages/#{messageid}")

    body = response.parse["attributes"]["body"]

    say(response.code)
    #say(body)
    encrypted_data = GPGME::Data.new(body)
    key = GPGME::Data.new(File.open($settings_file["keyfile_location"]))

    ctx = GPGME::Ctx.new :passphrase_callback => method(:passfunc)
    ctx.import_keys key

    decrypted = ctx.decrypt encrypted_data
    decrypted.seek(0)
    say(decrypted)
  end
###################################
  desc 'setpk', 'set path for your private key'
  def pk
    path = ask 'Enter your private key location:'
    say(" PATH SET TO #{$settings_file["keyfile_location"]}")
    say('You will still need your password to access the key')
    $settings_file["keyfile_location"] = path
    File.write("settings.yml",$settings_file.to_yaml)
  end
end

WisprCLI.start(ARGV)
