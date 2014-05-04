		# prompt for 
		#  FC api key
    api_key = ENV['FULL_CONTACT_API_KEY']

    #  podio api key / secret / username / password
    podio_api_key = ENV['PODIO_CLIENT_ID']
    podio_api_secret = ENV['PODIO_CLIENT_SECRET']
    Podio.setup(:api_url => 'https://api.podio.com', :api_key => podio_api_key, :api_secret => podio_api_secret)

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
		app_id = 7628956

		# read 1st page of results from FC
		FullContact.configure do |config|
		 	config.api_key = api_key
		end

		cr = FullContact.card_reader

		# for each page of results

		# for each result, import into podio
		cr.results.each do |result|
			Podio::Item.create({
				:fields => {
          {"type"=>"text",
      "field_id"=>59156200,
      "label"=>"Full Name",
      "values"=>[{"value"=>cr.contact.name.given_name + " " + cr.contact.name.family_name}],
      "config"=>
       {"settings"=>{"size"=>"small"}, "mapping"=>nil, "label"=>"Full Name"},
      "external_id"=>"full-name"},
     {"type"=>"text",
      "field_id"=>59156201,
      "label"=>"Title",
      "values"=>[{"value"=>cr.contact.organizations.select{ |i| i[:is_primary] == true }.title}],
      "config"=>
       {"settings"=>{"size"=>"small"}, "mapping"=>nil, "label"=>"Title"},
      "external_id"=>"title"}          
        }
    })
    end
