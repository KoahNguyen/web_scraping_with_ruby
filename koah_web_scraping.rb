require 'httparty'
require 'nokogiri'
require 'pry'
require 'csv'

class KoahScraper
  class << self
    def call(n_page)
      init_variables(n_page)
      first_call
      @n_page.times { second_call } if @n_page.positive?
      csv_writer
      # Pry.start(binding)
    end

    private

    def init_variables(n_page)
      @domain        = 'https://www.amazon.com'
      @url           = @domain + '/s/ref=nb_sb_noss?url=node%3D3952&field-keywords='
      @product_links = []
      @n_page        = n_page > 1 ? n_page - 1 : 0
    end

    def first_call
      parse_page_builder(@url)
      next_link_builder(true)
      product_links_builder(true)
    end

    def second_call
      parse_page_builder(@next_link)
      next_link_builder
      product_links_builder
    end

    def parse_page_builder(link)
      page        = HTTParty.get(link)
      @parse_page = Nokogiri::HTML(page)
    end

    def next_link_builder(first_time = false)
      url_option = @parse_page.at_css('#pagnNextLink')&.attribute('href')&.value
      while url_option.nil? do
        sleep 3
        if first_time
          parse_page_builder(@url)
        else
          parse_page_builder(@next_link)
        end
        url_option = @parse_page.at_css('#pagnNextLink')&.attribute('href')&.value
      end
      @next_link = "@domain#{url_option}"
    end

    def product_links_builder(first_time = false)
      search_results = if first_time
                         @parse_page.css('div#search-results > div#mainResults > ul > li')
                       else
                         @parse_page.css('div#resultsCol > div#centerMinus > div#atfResults > ul > li')
                       end
      search_results.each do |result|
        @product_links << result.at_css('div > div > div > div[2] > div[2] > div[1] > a').attribute('href').value.split('#').first
      end
    end

    def csv_writer
      products_csv = CSV.open('products.csv', 'w', col_sep: '|')
      @product_links.each do |link|
        products_csv << product_data(link)
      end
      products_csv.close
    end

    def product_data(link)
      product_title      = product_title_parse(link)
      product_author     = product_author_parse
      product_image_link = product_image_link_parse
      product_content    = product_content_parse
      [product_title, product_author, product_image_link, product_content]
    end

    def product_title_parse(link)
      parse_page_builder(link)
      product_title = @parse_page.at_css('#productTitle')&.text
      while product_title.nil? do
        sleep 3
        parse_page_builder(link)
        product_title = @parse_page.at_css('#productTitle')&.text
      end
      product_title
    end

    def product_author_parse
      product_author = @parse_page.at_css('#byline > span > span.a-declarative > a.a-link-normal.contributorNameID')&.text
      product_author = @parse_page.at_css('#byline > span')&.text&.tr("\n\t",'')&.gsub(/\s+/, " ")&.strip if product_author.nil?
      product_author
    end

    def product_image_link_parse
      @parse_page.at_css('#imgBlkFront')&.attribute('src')&.value
    end

    def product_content_parse
      @parse_page.at_css('div#bookDescription_feature_div > noscript > div')&.to_html&.tr("\n\t",'')
    end
  end
end

def koah_web_scraping(n_page)
  start_time = Time.now
  KoahScraper.call(n_page)
  end_time = Time.now
  runtime = end_time - start_time
  puts "Runtime: #{runtime} seconds"
end

if ARGV[0].nil?
  puts 'ruby koah_web_scraping.rb [n_page]'
  puts
  puts 'OPTIONS'
  puts '  n_page: page number'
  puts
  puts 'EXAMPLE'
  puts '  ruby koah_web_scraping.rb 4'
else
  n_page = ARGV[0].to_i
  koah_web_scraping(n_page)
end
