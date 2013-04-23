## Module to Interface with Feed Mapping Rake Task that Lets an User to Map Nodes Using
## XSLT (through web forms) and Attributes of a database object.

require 'open-uri'
require 'net/http'

module FeedHelper
  include Magick
  
  @logger = Logger.new(STDOUT)
  @logger.level = Logger::DEBUG
  
  # Open File from Local Filesystem or from URL. Return Nokogiri object.
  def self.parse_xml_doc(feed_obj)
     doc = nil
     feed_location = feed_obj.feed_location
     if feed_obj.path_date_format.present?
       today = Date.today.strftime(feed_obj.path_date_format)
       feed_location.gsub!(/@Date/, today)
     end
   
     if feed_obj.delivery_method == "FTP"
       begin
         f = File.open(feed_location, "r")
         doc = Nokogiri::XML(f)
       rescue => e
         @logger.info("Error Parsing Local XML Document for #{feed_obj.client_name}")
         @logger.info(e.message)
         doc = nil
       ensure
         f.close if !f.nil?
       end
     else
      begin
        doc = Nokogiri::XML(open(feed_location))
      rescue => e
        @logger.info("Error Parsing HTML Document for #{feed_obj.client_name}")
        @logger.info(e.message)
        doc = nil
      end
    end
  
    return doc
  end
  
  # Return Value of Node from Root Node or an optional value if the Specific node isn't found.
  def self.val (root_obj, node, alternate_value = nil)
    n = nil
    n = root_obj.xpath(node) if node && !node.blank?
    if n.present?
      begin
        txt = n.first.text
        return txt
      rescue => e
        @logger.info(e.message)
        return ""
      end
    else
      return alternate_value.present? ? alternate_value : ""
    end
  end
  
  # Calculates the min or max of an attribute from the floorplans collection.
  # min_or_max: Must be string 'min' or 'max'
  def self.calculate_min_or_max (min_or_max, attribute, floorplans)
    items = floorplans.collect {|plan| plan[attribute] }
    if items.size > 0 && min_or_max =~ /min|max/
      if min_or_max == "min"
        return items.min
      elsif min_or_max == "max"
        return items.max
      end
    else
      return 0
    end
  end
  
  ## Grabs Image Nodes from XML Files, Downloads the Image from URL and Stores the Image on Database
  def self.write_images(subdivision, root_node, images_node, title_node, caption_node)
    
    images = images_node.present? ? root_node.xpath(images_node) : [] ## Root Node is a parent of Image Node
    
    for image in images
      url = image.text
      url.gsub!(/https:/, "http:")
      filename = url
      
      ## Check if Image is already stored in Database. Don't Download and Process if it is.
      asset = ImagesCollection.where(:path => filename).first
      
      if asset
        @logger.info("Found image from #{url}. Will not update")
        asset.updated_at = Time.now
        asset.save
      else
        img = self.process_image(url) ## Get RMagick Image
        if !img.nil?
          title = self.val(image, title_node)
          caption = self.val(image, caption_node)

          ## Create a Tempfile. Emulate File as Being Uploaded Because Current Gem Won't Allow Another Kind of File.
          Tempfile.open("feedfile") do |tmp|
            tmp.binmode
            tmp << img.to_blob
            tmp.rewind
            attachment = ActionDispatch::Http::UploadedFile.new({:filename => filename, :tempfile => tmp})
            
            ## Store Image in Database
            begin
              ImageCollection.create!(:type => "Image", :file => attachment, :title => title, 
                                      :caption => caption, :path => filename)
            rescue => e
              @logger.info(e.message)
            end
          end
        end
      end
    end
  end
  
  ## Downloads Image from URL. Creates RMagick Image Object and Does Image Editing to it.
  ## Returns an RMagick Image Object
  def self.process_image(image_url)
    image_url.gsub!(" ", "%20")
    image, response = nil, nil
    begin
      @logger.info("Downloading image from #{image_url}")
      response = Net::HTTP.get_response(URI.parse(image_url))
    rescue
      @logger.info("There was a problem downloading the image from #{image_url}")
    end
    
    if !response.nil?
      begin
        image = Image.from_blob(response.body).first
        image.density = "72x72"
        image.trim!
        image.resize_to_fit!(700, 700) if image.rows > 700 || image.columns > 700  ## Resize if more than 700x700
        image.format = "JPG" if image.format =~ /pdf/i ## Convert PDF to JPG
      rescue
        @logger.info("There was a problem processing image at #{image_url}. It will not be saved")
      end
    end
    return image
  end
  
end