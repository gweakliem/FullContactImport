require 'podio'
require 'fullcontact'
require 'date'
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

def get_full_contact_field(record,field_id, selector_value, value_field_name)
  field = record.find{ |i| i[field_id] == selector_value }
  field ? field[value_field_name]:nil
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
			Podio::Item.create(app_id,{
				:fields => {
          'full-name' => result.contact.name.given_name + " " + result.contact.name.family_name,
          'title'=> get_full_contact_field(result.contact.organizations,:is_primary,true,:title),
          'company'=>get_full_contact_field(result.contact.organizations,:is_primary,true,:name),
          'phone'=>get_full_contact_field(result.contact.phone_numbers,:type,"Work",:value),
          'cell-phone'=>get_full_contact_field(result.contact.phone_numbers,:type,"Mobile",:value),
          'email'=>get_full_contact_field(result.contact.emails,:type,"Work",:value),
          'fax'=>get_full_contact_field(result.contact.phone_numbers,:type,"Work Fax",:value),
          'street-address'=>get_full_contact_field(result.contact.addresses,:type,"Work",:street_address),
          'city'=>get_full_contact_field(result.contact.addresses,:type, "Work",:locality ),
          'state'=>get_full_contact_field(result.contact.addresses,:type,"Work",:region),
          'zip'=>get_full_contact_field(result.contact.addresses,:type,"Work",:postal_code),
          "date-entered"=> {"start"=>DateTime.now.strftime("%Y-%m-%d %H:%M:%S"),"end"=>DateTime.now.strftime("%Y-%m-%d %H:%M:%S")}
      }
    })
    #end
