require 'podio'
require 'fullcontact'
require 'open-uri'
require 'date'
require 'pp'
require 'hashie/rash'
require 'optparse'

def field_values_by_external_id(external_id, options = {})
      if self.fields.present?
        field = self.fields.find { |field| field['external_id'] == external_id }
        if field
          values = field['values']
          if options[:simple]
            values.first['value']
          else
            values
          end
        else
          nil
        end
      else
        nil
      end
    end

def get_full_contact_field(record,selector_key, selector_value, value_field_name, index = 0)
  fields = []
  if record != nil
    fields = record.select{ |i| i[selector_key] == selector_value } 
  end
  fields[index][value_field_name] if (fields.length > index)
end

def create_podio_embed(record,selector_key, selector_value, value_field_name, index = 0)
  embed_target = get_full_contact_field(record,selector_key, selector_value, value_field_name, index) 
  embed_target ? Podio::Embed.create( embed_target ) : nil
end

def upload_file_attachment(record,selector_key, selector_value, value_field_name, label, index = 0)
  field_value = get_full_contact_field(record,selector_key, selector_value,value_field_name, index)
  Podio::FileAttachment.upload_from_url(field_value) if field_value
end

def maybe_add_item_field(fields, field_name,record,selector_key, selector_value, value_field_name, index = 0)
  field_value = get_full_contact_field(record,selector_key, selector_value, value_field_name, index)
  fields[field_name]=field_value if field_value
end

def create_embed(embed_obj)
  result = nil
  if (embed_obj)
    result = {"embed" => embed_obj.embed_id}
    result["file"] = embed_obj.files[0].file_id if (embed_obj.files.length > 0)
  end
  return result
end

options = OpenStruct.new
options.org_label = nil
options.space_label = nil
options.app_label = nil
options.fc_api_key = ''
options.podio_client_id = ''
options.podio_client_secret = ''
options.podio_username = ''
options.podio_password = ''

opt_parser = OptionParser.new do |opts|
  opts.banner = "Usage: scratch.rb [options]"

  opts.separator ""
  opts.separator "Specific options:"

  # Mandatory argument.
  opts.on("-o", "--org ORG_LABEL",
          "Organization label") do |label|
    options.org_label = label
  end
  opts.on("-s", "--space SPACE_LABEL",
          "Space Label") do | label |
    options.space_label = label
  end
  opts.on("-a", "--app APP_LABEL",
          "App Label") do | label |
    options.app_label = label
  end
  # TODO: move ENV params to command line
end # opt_parser

opt_parser.parse!(ARGV)

if options.org_label.nil? || options.space_label.nil? || options.app_label.nil? 
  puts opt_parser.help
  exit(1)
end

FullContact.configure do |config|
  config.api_key = ENV['FULL_CONTACT_API_KEY']
end

#  podio api key / secret / username / password
Podio.setup(:api_url => 'https://api.podio.com', :api_key => ENV['PODIO_CLIENT_ID'], :api_secret => ENV['PODIO_CLIENT_SECRET'])
Podio.client.authenticate_with_credentials(ENV['PODIO_USERNAME'], ENV['PODIO_PASSWORD'])

app = Podio::Application.find_by_org_space_and_app_labels(options.org_label, options.space_label, options.app_label)
app_id = app.app_id

# read 1st page of results from FC
cr = Hashie::Rash.new({:current_page => -1, :total_pages => 0})

# for each page of results
while cr.current_page < cr.total_pages
  cr = FullContact.card_reader({:page => cr.current_page+1})
	puts "Starting Full Contact page #{cr.current_page} of #{cr.total_pages}, #{cr.total_records} total records"
  # for each result, import into podio
	cr.results.each do |result|
    #pp(result)
    vcard_url_attach = Podio::Embed.create( result.v_card_url ) 
    business_card_front_attach = upload_file_attachment(result.contact.photos,:type, "BusinessCard",:value, "Business Card Front")
    business_card_back_attach = upload_file_attachment(result.contact.photos,:type, "BusinessCard",:value, "Business Card Back",1) 
    website_url_embed = create_podio_embed(result.contact.urls,:type, "Company", :value) 
    facebook_url_embed = create_podio_embed(result.contact.accounts, :domain, "facebook.com", :url_string) 
    twitter_url_embed = create_podio_embed(result.contact.accounts, :domain, "twitter.com", :url_string) 

    new_item_fields = {
        "date-entered"=> {"start"=>DateTime.now.strftime("%Y-%m-%d %H:%M:%S"),"end"=>DateTime.now.strftime("%Y-%m-%d %H:%M:%S")}
    }

    if result.contact.name != nil 
      new_item_fields['full-name'] = "#{result.contact.name.given_name} #{result.contact.name.family_name}"
    end 
    maybe_add_item_field(new_item_fields,'title',result.contact.organizations,:is_primary,true,:title)
    maybe_add_item_field(new_item_fields,'company',result.contact.organizations,:is_primary,true,:name)
    new_item_fields["location-met"] = "#{result.params.latitude},#{result.params.longitude}" if (result.params.latitude && result.params.longitude)
    maybe_add_item_field(new_item_fields,'phone',result.contact.phone_numbers,:type,"Work",:value)
    maybe_add_item_field(new_item_fields,'cell-phone',result.contact.phone_numbers,:type,"Mobile",:value)
    maybe_add_item_field(new_item_fields,'email',result.contact.emails,:type,"Work",:value)
    maybe_add_item_field(new_item_fields,'fax',result.contact.phone_numbers,:type,"Work Fax",:value)
    maybe_add_item_field(new_item_fields,'street-address',result.contact.addresses,:type,"Work",:street_address)
    maybe_add_item_field(new_item_fields,'city',result.contact.addresses,:type, "Work",:locality )
    maybe_add_item_field(new_item_fields,'state',result.contact.addresses,:type,"Work",:region)
    maybe_add_item_field(new_item_fields,'zip',result.contact.addresses,:type,"Work",:postal_code)
    new_item_fields["website"] = create_embed(website_url_embed) if website_url_embed
    new_item_fields["twitter-url"] = create_embed(twitter_url_embed) if twitter_url_embed
    new_item_fields["facebook-url"] = create_embed(facebook_url_embed) if facebook_url_embed
    new_item_fields["vcard-link"] =   {"url" => vcard_url_attach.resolved_url, "embed" => vcard_url_attach.embed_id} if vcard_url_attach
    new_item_fields["business-card-front"] = business_card_front_attach.file_id if business_card_front_attach
    new_item_fields["business-card-back"] = business_card_back_attach.file_id if business_card_back_attach

    #pp(new_item_fields)
		Podio::Item.create(app_id,{:fields => new_item_fields})
  end
end
