require 'net/http'
require 'uri'
require 'cgi'
require 'http_encoding_helper'
require 'rexml/document'

class ITMS
  class App
    attr_accessor :name, :url, :image, :id, :price, :category, :author_name, :author_id, :description, :screenshot_url

    def self.from_search(name, url, image, id, price, category)
      # not everything comes back from a search result (description, shots..)
      app = ITMS::App.new
      app.url = url
      app.image = image
      app.id = id
      app.price = price
      app.category = category
      app
    end
  end

  class AppStore
    @@host = "ax.itunes.apple.com"
    @@search_path = "/WebObjects/MZSearch.woa/wa/advancedSearch?submit=seeAllLockups&media=software&entity=software&softwareTerm="
    @@app_path = "/WebObjects/MZStore.woa/wa/viewSoftware?mt=8&id="
    @@new_path = "/WebObjects/MZStore.woa/wa/viewRoom?fcId=285114016&sortMode=2&id=25204"


    def self.search(q)
      results = []
      body = retrieve(@@search_path + CGI::escape(q))
      doc = REXML::Document.new(body)
      doc.root.each_element("//View/ScrollView/VBoxView/View/MatrixView/VBoxView/MatrixView/VBoxView/View/VBoxView/VBoxView/VBoxView/MatrixView/HBoxView/VBoxView/MatrixView") do |app|
        url = app.elements['GotoURL'].attributes["url"]
        id = parse_id_from_url(url)
        name = app.elements['GotoURL'].attributes["draggingName"]
        image = app.elements['GotoURL'].elements['View'].elements['PictureView'].attributes["url"]
        price = app.elements['VBoxView'].elements['VBoxView'].elements['HBoxView'].elements['VBoxView[2]'].elements['Test'].elements['Buy'].elements['PictureButtonView'].attributes["alt"].split(": ")[1]
        category = app.elements['VBoxView'].elements['HBoxView[2]'].elements['TextView'].elements['SetFontStyle'].elements['GotoURL'].text.strip
        results << ITMS::App.from_search(name, url, image, id, price, category)
      end
      results.empty? ? nil : results
    end



    def self.new_apps
      results = []
      body = retrieve(@@new_path)
      doc = REXML::Document.new(body)
      doc.root.each_element("//View/ScrollView/VBoxView/View/MatrixView/View/VBoxView/HBoxView/VBoxView/VBoxView/View/VBoxView[2]/VBoxView/VBoxView/MatrixView/HBoxView/VBoxView/MatrixView") do |app|
        name = app.elements['GotoURL'].attributes["draggingName"]
        url = app.elements['GotoURL'].attributes["url"]
        id = parse_id_from_url(url)
        image = app.elements['GotoURL'].elements['View'].elements['PictureView'].attributes["url"]
        price = category.elements['VBoxView'].elements['VBoxView'].elements['HBoxView'].elements['VBoxView'].elements['TextView'].elements['SetFontStyle'].elements['b']
        category = app.elements['VBoxView'].elements['HBoxView[2]'].elements['TextView'].elements['SetFontStyle'].elements['GotoURL'].attributes['draggingName']
        results << ITMS::App.from_search(name, url, image, id, price, category)
      end

      results.empty? ? nil : results
    end




    def self.app(id)
      id = id.to_i
      url = @@app_path + CGI::escape(id.to_s)
      body = retrieve(url)
      doc = REXML::Document.new(body)
      app = ITMS::App.new

      app.id = id
      unless (id.is_a?(Integer) or id.is_a?(Bignum)) and id >= 1
        raise Exception, "Invalid app id: #{id}, #{id.class}"
      end


      a = doc.root
      begin
        view = a.elements['View'].elements['ScrollView'].elements['VBoxView'].elements['View'].elements['MatrixView']
      rescue
        raise Exception, "Invalid page for app #{id}"
      end

      begin
        app.name = a.elements['iTunes'].text.strip
      rescue 
      end

      begin
        app.author_name = view.elements['MatrixView'].elements['VBoxView[1]'].elements['GotoURL'].attributes['draggingName'].strip
      rescue
      end

      begin
        author_url = view.elements['MatrixView'].elements['VBoxView[1]'].elements['GotoURL'].attributes['url']
        app.author_id = parse_id_from_url(author_url)
      rescue
      end

      begin
        # such a hack
        description_unformatted = view.elements['MatrixView'].elements['VBoxView[2]'].elements['VBoxView[1]'].elements['TextView[2]'].elements['SetFontStyle'].to_s
        r = Regexp.compile("<SetFontStyle.*?>(.*?)</SetFontStyle>", Regexp::MULTILINE)
        app.description = r.match(description_unformatted)[1]
      rescue
      end

      begin
        price_unformatted = view.elements['MatrixView'].elements['VBoxView'].elements['VBoxView'].elements['MatrixView'].elements['VBoxView'].elements['VBoxView'].elements['HBoxView'].elements['VBoxView'].elements['TextView'].elements['SetFontStyle'].elements['b'].to_s
        r2 = Regexp.compile("<b>(.*?)</b>")
        app.price = r2.match(price_unformatted)[1]
      rescue
      end

      begin
        app.category = view.elements['MatrixView'].elements['VBoxView[1]'].elements['VBoxView[1]'].elements['MatrixView'].elements['VBoxView'].elements['HBoxView[2]'].elements['TextView'].elements['SetFontStyle'].text.split(": ")[1].strip
      rescue
      end

      begin
        app.image = view.elements['MatrixView'].elements['VBoxView'].elements['VBoxView'].elements['MatrixView'].elements['GotoURL'].elements['PictureView'].attributes["url"]
      rescue
      end

      begin
        app.screenshot_url =  view.elements['MatrixView'].elements['VBoxView'].elements['View[2]'].elements['View'].elements['View'].elements['VBoxView'].elements['View'].elements['VBoxView'].elements['HBoxView'].elements['LoadFrameURL'].elements['PictureView'].attributes["url"]
      rescue
      end

      return app
    end
    
    def self.retrieve(path)
      http = Net::HTTP.new(@@host, 80)
      http.start do |http|
        req = Net::HTTP::Get.new(path, 
                                 {"User-Agent" => "iTunes/8.0.2 (Macintosh; U; PPC Mac OS X 10.4.1)" })
        response = http.request(req)
        return response.plain_body
      end
    end

    def self.parse_id_from_url(url)
      URI.parse(url).query.split("&").each do |p|
        return p.split("=")[1] if p[0..2] == "id="
      end
    end

    
  end
end
