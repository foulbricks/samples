## Two Classes to Interface with the Yelp API

## Yelp Base Class. 
class Yelp::Base
  def initialize
  end
  
  ## Authenticate from YAML file stored on "/config/api.yml"
  def authenticate
    api_config = YAML::load(File.read(Rails.root.to_s + "/config/api.yml"))
    yelp = api_config['yelp']
    
    consumer = OAuth::Consumer.new(yelp['consumer_key'], yelp['consumer_secret'], {:site => "http://api.yelp.com"})
    OAuth::AccessToken.new(consumer, yelp['token'], yelp['token_secret'])
  end
end

## Business Search From Yelp
class Yelp::BusinessSearch < Yelp::Base
  attr_reader :url
  
  def initialize(business_type, location, limit=nil)
    @url = "/v2/search?term=#{URI.escape(business_type)}&#{URI.escape(location)}"
    @url += "&limit=#{limit}" if limit
  end
  
  ## Return a Hash of Popular Places. Limit each with 'limit' parameter
  def self.popular_places(location, limit)
    {
      :restaurants => restaurants(location, limit),
      :shopping => shopping(location, limit),
      :bars_and_clubs => bars_and_clubs(location, limit),
      :personal_services => personal_services(location, limit)
    }
  end
  
  def self.restaurants(location, limit = nil)
    new('restaurants', location, limit).results
  end
  
  def self.shopping(location, limit = nil)
    new('shopping', location, limit).results
  end
  
  def self.bars_and_clubs(location, limit = nil)
    new('bars and clubs', location, limit).results
  end
  
  def self.personal_services(location, limit = nil)
    new('personal services', location, limit).results
  end
  
  ## Get A Hash of Results From An API call to Yelp
  def results
    begin
      access_token = authenticate
      response = nil
      
      ## Issue an Exception If it is taking too long.
      Timeout.timeout(3) {
        response = access_token.get(self.url).body
      }
      
      json_response = ActiveSupport::JSON.decode(response)
      
      if json_response['businesses'].present?
        json_response['businesses'].map do |c|
          {
            :id   =>         c['id'], 
            :name         => c['name'], 
            :street       => c['location']['address'].join(" "),
            :city         => c['location']['city'],
            :state        => c['location']['state_code'],
            :phone        => c['phone'],
            :rating       => c['rating'],
            :rating_img   => c['rating_img_url'],
            :url          => c['url'],
            :review_count => c['review_count']
          }
        end
      else
        puts response
        return []
      end
    rescue Timeout::Error => e
      puts e.message
      return []
    rescue => e
      puts e.message
      return []
    end
  end
  
end