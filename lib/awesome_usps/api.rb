# =========================================================================================
# I think it's pretty awesome how Matt organized the Api's features by module.
# 
# But there's a lot of refactoring that can be done.
#
#   - Tests like `canned_tracking` in the Tracking module should be moved to unit tests
#   - The case statement in Gateway should be extracted into separate methods
#   - ...
#
# I'm going to start the refactor with AddressVerification because that is what I need.
# Some of the other modules may not work until the refactor is complete.
# =========================================================================================



require 'rubygems'
require 'hpricot'
require 'net/https'
require 'active_support/all'

# !todo: figure out how to do auto-include to load modules on demand.
require 'awesome_usps/address_verification'
# require 'awesome_usps/delivery_and_signature_confirmation'
# require 'awesome_usps/electric_merchandis_return'
# require 'awesome_usps/express_mail'
# require 'awesome_usps/international_mail_labels'
# require 'awesome_usps/open_distrubute_priority'
# require 'awesome_usps/service_standard'
# require 'awesome_usps/shipping'
# require 'awesome_usps/tracking'


module AwesomeUsps
  class Api
    include AwesomeUsps::AddressVerification
    # include AwesomeUsps::DeliveryAndSignatureConfirmation
    # include AwesomeUsps::ElectricMerchandisReturn
    # include AwesomeUsps::ExpressMail
    # include AwesomeUsps::InternationalMailLabels
    # include AwesomeUsps::OpenDistrubutePriority
    # include AwesomeUsps::ServiceStandard
    # include AwesomeUsps::Shipping
    # include AwesomeUsps::Tracking
    
    
    
    def initialize(*args)
      options = args.extract_options!
      @username = args.first || options[:username]
      @server = options[:server] || :test
      
      raise ERROR_MSG if @username.blank?
    end
    
    
    
    def marshal_request!(api, xml_request, options={})
      xml_request = wrap_xml_request_in_api_container(api, xml_request)
      response = send_request_with_retries!(api, xml_request, options)
      raise("USPS plugin settings are wrong #{response}") unless successful?(response)
      response.body
    end
    
    def wrap_xml_request_in_api_container(api, xml_request)
      container = xml_container_for_api_request(api)
      "<#{container} USERID=\"#{@username}\">#{xml_request}</#{container}>"
    end
    
    def xml_container_for_api_request(api)
      API_CONTAINERS[api]
    end
    
    def successful?(response)
      response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
    end
    
    
    
    def send_request_with_retries!(api, xml_request, options={})
      retries = MAX_RETRIES
      begin
        send_request!(api, xml_request, options)
      rescue Timeout::Error
        if retries > 0
          retries -= 1
          retry
        else
          raise Timeout::Error
        end
      end
    end
    
    def send_request!(api, xml_request, options={})
      url = URI.parse(server_url)
      request = create_request(url, api, xml_request)
      puts "[awesome] sending request to '#{normalize_api_name(api)}' API at #{server_url}"
      # puts xml_request
      http = create_http(url)
      http.start {|http| http.request(request)}
    end
    
    def server_url(server=@server)
      case server
      when :production, :live;    production_url
      when :secure, :ssl;         secure_url
      else                        test_url
      end
    end
    
    def test_url
      TEST_URL
    end
    
    def production_url
      PRODUCTION_URL
    end
    
    def secure_url
      SECURE_URL
    end
    
    
    
  private
    
    
    
    def create_request(url, api, xml)
      request = Net::HTTP::Post.new(url.path)
      request.set_form_data({'API' => normalize_api_name(api), 'XML' => xml})
      request
    end
    
    def normalize_api_name(api)
      api.is_a?(Symbol) ? api.to_s.camelize : api
    end
    
    def create_http(url)
      http = Net::HTTP.new(url.host, url.port)
      http.open_timeout = 2
      http.read_timeout = 2
      if url.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http
    end
    
    
    
    MAX_RETRIES     = 3
    TEST_URL        = 'http://testing.shippingapis.com/ShippingAPITest.dll'
    PRODUCTION_URL  = 'http://production.shippingapis.com/ShippingAPI.dll'
    SECURE_URL      = 'https://secure.shippingapis.com/ShippingAPI.dll'
    API_CONTAINERS  = {
      :verify                 => 'AddressValidateRequest',
      :zip_code_lookup        => 'ZipCodeLookupRequest',
      :city_state_lookup      => 'CityStateLookupRequest'
    }
    
  end
end
