require 'thor'
require 'http'
require 'httparty'
require 'gpgme'
require 'json'
require 'yaml'
require 'base64'
require 'rbnacl/libsodium'

# wispr cli class
class WisprCLI < Thor
  include GPGME
  include HTTParty
  $settings_file = YAML::load_file "./settings/settings.yml"
  $auth_file = YAML::load_file "./settings/token.yml"
  base_uri  $settings_file["URI"]
########################################
  desc 'login', 'login to wispr'
  def login
    def sign(message)
      skey = Base64.strict_decode64($settings_file["SIGNING_KEY"])
      signing_key = RbNaCl::SigningKey.new(skey)
      signature_raw = signing_key.sign(message.to_json)
      Base64.strict_encode64(signature_raw)
    end
    username = ask 'Enter your username:'
    password = ask 'Enter your password:' , :echo => false
    # say("connecting to #{self.class.base_uri}/accounts/authenticate", :green)
    say("logging in, please wait a moment!", :green)
    message = { username: username, password: password }
    response = HTTP.post("#{self.class.base_uri}/accounts/authenticate",
                         json: { data: message,
                                 signature: sign(message)})
    say(response.status) # need to add some validation here. if not 200 dies
    token = response.parse

    $auth_file = token.to_yaml
    File.write("./settings/token.yml", $auth_file)
  end
  #####################################
  desc 'getmessage', 'gets message with id and decrypts it using keyfile'
  def getmessage(messageid)
    # function to ask for keyfile password
    def passfunc(obj, uid_hint, passphrase_info, prev_was_bad, fd)
      io = IO.for_fd(fd, 'w')
      io.puts "PASSPHRASE"
      io.flush
    end

    currentid = $auth_file["account"]["id"]
    response = HTTP.auth("Bearer #{$auth_file["auth_token"]}")
                   .get("#{self.class.base_uri}/messages/#{messageid}")
    say(response)
    body = response.parse["attributes"]["body"]

    say(response.code, :yellow)

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
  def setpk
    path = ask 'Enter your private key location:' , :path => true
    say("PATH SET TO #{path}", :green)
    say('You will still need your password to access the key', :red)
    $settings_file["keyfile_location"] = path
    File.write("./settings/settings.yml",$settings_file.to_yaml)
  end
######################################
  desc 'setserv', 'url to connect to'
  def setserv
    url = ask 'Enter URL of wispr server, do not input /api/v1/.. unless you
     know what you are doing, it is appended automaticaly:', :path => true
    say("URL SET TO #{url}", :green)
    $settings_file["URI"] = "#{url}/api/v1/"
    File.write("./settings/settings.yml",$settings_file.to_yaml)
  end
end

WisprCLI.start(ARGV)
