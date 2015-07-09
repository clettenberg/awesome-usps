require 'builder'


module AwesomeUsps
  module AddressVerification
    
    
    
    # Examines address and fills in missing information. Address must include city & state or the zip to be processed.
    # Can do up to an array of five
    def verify_address(*locations)
      marshal_address_verification_request!(:verify, locations)
    end
    
    def zip_lookup(*locations)
      marshal_address_verification_request!(:zip_code_lookup, locations)
    end
    
    def city_state_lookup(*locations)
      marshal_address_verification_request!(:city_state_lookup, locations)
    end
    
    
    
  private
    
    
    
    def marshal_address_verification_request!(api, locations)
      locations = locations.first if locations.first.is_a?(Array)
      request   = write_xml_of_locations              api, locations
      puts request
      response  = marshal_request!                    api, request
      puts response
                  parse_address_verification_response response
    end
    
    
    
    # Builder is a pain in the ass
    def write_xml_of_locations(api, locations)
      xml = ""
      # xm = Builder::XmlMarkup.new(xml)
      locations.each_with_index do |location, i|
        h = normalize_location_hash(location)
        xml << <<-XML
        <Address ID="#{i}">
          <FirmName>#{h[:firm_name]}</FirmName>
          <Address1>#{h[:address1]}</Address1>
          <Address2>#{h[:address2]}</Address2>
          <City>#{h[:city]}</City>
          <State>#{h[:state]}</State>
          <Zip5>#{h[:zip5]}</Zip5>
          <Zip4>#{h[:zip4]}</Zip4>
        </Address>
        XML
        # xm.Address("ID" => i.to_s) do
        #   xm.FirmName(l.firm_name)
        #   xm.Address1(l.address1)
        #   xm.Address2(l.address2)
        #   if api != :city_state_lookup
        #     xm.City(l.city)
        #     xm.State(l.state)
        #   end
        #   if api != :zip_code_lookup
        #     xm.Zip5(l.zip5)
        #     xm.Zip4(l.zip4)
        #   end
        # end
      end
      xml
    end
    
    
    
    def normalize_location_hash(hash)
      zip = hash[:zip] || hash[:zip_code] || hash[:postal] || hash[:postal_code] || ""
      {
        :firm_name => hash[:firm_name] || hash[:name] || hash[:first_name] || hash[:company],
        :address1 => hash[:address1],
        :address2 => hash[:address2] || hash[:street],
        :city => hash[:city],
        :state => hash[:state] || hash[:province] || hash[:territory] || hash[:region],
        :zip5 => hash[:zip5] || (zip.match(/(\d{5})(?:-\d{4})?/)||[])[1],
        :zip4 => hash[:zip4] || (zip.match(/\d{5}-(\d{4})/)||[])[1]
      }
    end
    
    
    
    # Parses the XML into an array broken up by each address.
    # For verify_address :verified will be false if multiple address were found.
    def parse_address_verification_response(xml)
      i = 0
      list_of_verified_addresses = []
      (Hpricot.parse(xml)/:address).each do |address|
        i+=1
        h = {}
        # Check if there was an error in an address element
        if address.search("error") != []
          return "Address number #{i} has the error '#{address.search("description").inner_html}' please fix before continuing"
        end
        if address.search("ReturnText") != []
          h[:verified] = false
        else
          h[:verified] = true
        end
        address.children.each { |elem| h[elem.name.to_sym] = elem.inner_text unless elem.inner_text.blank? }
        list_of_verified_addresses << h
      end
      #Check if there was an error in the basic XML formating
      if list_of_verified_addresses == []
        error = Hpricot.parse(xml)/:error
        return error.search("description").inner_html
      end
      return list_of_verified_addresses
    end
    
    
    
  end
end