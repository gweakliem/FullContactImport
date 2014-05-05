require 'podio'
require 'fullcontact'
require 'open-uri'
require 'date'
require 'pp'

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
  fields = record.select{ |i| i[selector_key] == selector_value } if record
  fields ? fields[index][value_field_name]:nil
end

def create_podio_embed(record,selector_key, selector_value, value_field_name, index = 0)
  embed_target = get_full_contact_field(record,selector_key, selector_value, value_field_name, index) 
  embed_target ? Podio::Embed.create( embed_target ) : nil
end

def upload_file_attachment(record,selector_key, selector_value, value_field_name, label, index = 0)
  field_value = get_full_contact_field(record,selector_key, selector_value,value_field_name, index)
  open(field_value) { |f| Podio::FileAttachment.upload(f, label)} if field_value
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

		# prompt for 
		#  FC api key
    api_key = ENV['FULL_CONTACT_API_KEY']

    #  podio api key / secret / username / password
    Podio.setup(:api_url => 'https://api.podio.com', :api_key => ENV['PODIO_CLIENT_ID'], :api_secret => ENV['PODIO_CLIENT_SECRET'])
    Podio.client.authenticate_with_credentials(ENV['PODIO_USERNAME'], ENV['PODIO_PASSWORD'])
		# look up podio organizations
		orgs = Podio::Organization.find_all

		# pick organization
		#Podio::Organization.find(608503)
		# org.name, org.org_id # 608503
		org_id = 608503

		# look up podio workspaces
		workspaces = Podio::Space.find_all_for_org(org_id)

		# pick podio workspace
		#ws.name, ws.space_id #=>2092311
		space_id = 2092311

		# look up applications in workspace
		apps = Podio::Application.find_all_for_space(space_id)

		# pick application
		#app.name, app.app_id # =>7628956
		app_id = 7961738

		# read 1st page of results from FC
		FullContact.configure do |config|
		 	config.api_key = api_key
		end

		cr = FullContact.card_reader

		# for each page of results

		# for each result, import into podio
		#cr.results.each do |result|
    result = cr.results[0]
    pp(result)
      vcard_url_attach = open( result.v_card_url) { |f| Podio::FileAttachment.upload( f, "vCard") }
      business_card_front_attach = upload_file_attachment(result.contact.photos,:type, "BusinessCard",:value, "Business Card Front")
      pp(business_card_front_attach)
      business_card_back_attach = upload_file_attachment(result.contact.photos,:type, "BusinessCard",:value, "Business Card Back",1) 
      website_url_embed = create_podio_embed(result.contact.urls,:type, "Company", :value) 
      facebook_url_embed = create_podio_embed(result.contact.accounts, :domain, "facebook.com", :url_string) 
      twitter_url_embed = create_podio_embed(result.contact.accounts, :domain, "twitter.com", :url_string) 

      new_item_fields = {
          'full-name' => result.contact.name.given_name + " " + result.contact.name.family_name,
          'title'=> get_full_contact_field(result.contact.organizations,:is_primary,true,:title),
          'company'=>get_full_contact_field(result.contact.organizations,:is_primary,true,:name),
          "date-entered"=> {"start"=>DateTime.now.strftime("%Y-%m-%d %H:%M:%S"),"end"=>DateTime.now.strftime("%Y-%m-%d %H:%M:%S")}
      }

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
      #new_item_fields["twitter-url"] = create_embed(twitter_url) if twitter_url_embed
      #new_item_fields["facebook-url"] = create_embed(facebook_url_embed) if facebook_url_embed
      #new_item_fields["vcard-link"] =   {"url" => vcard_url_attach.link, "file" => vcard_url_attach.file_id} if vcard_url_attach
      new_item_fields["business-card-front"] = business_card_front_attach.file_id if business_card_front_attach
      #new_item_fields["business-card-back"] = { "url" => business_card_back_attach.link, "file" => business_card_back_attach.file_id} if business_card_back_attach

      pp(new_item_fields)
			Podio::Item.create(app_id,{
				:fields => new_item_fields
    })
    #end
