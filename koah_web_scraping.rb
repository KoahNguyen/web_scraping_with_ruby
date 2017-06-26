require 'httparty'
require 'nokogiri'
require 'pry'
require 'csv'

class KoahScraper
  def initialize(n_page)
    @domain = 'https://www.amazon.com'
    @url = @domain + '/s/ref=nb_sb_noss?url=node%3D3952&field-keywords='
    @product_links = []
    @next_link = ''
    @n_page = n_page > 1 ? n_page - 1 : 0
  end

  def call
    first_call
    @n_page.times { second_call } if @n_page.positive?
    csv_writer
    # Pry.start(binding)
  end

  private

  def first_call
    page = HTTParty.get(@url)
    parse_page = Nokogiri::HTML(page)
    @next_link = @domain + parse_page.at_css('#pagnNextLink')&.attribute('href')&.value
    while @next_link.nil? do
      sleep 3
      page = HTTParty.get(@url)
      parse_page = Nokogiri::HTML(page)
      @next_link = @domain + parse_page.at_css('#pagnNextLink')&.attribute('href')&.value
    end
    search_results = parse_page.css('div#search-results > div#mainResults > ul > li')
    search_results.each do |result|
      @product_links << result.at_css('div > div > div > div[2] > div[2] > div[1] > a').attribute('href').value.split('#').first
    end
  end

  def second_call
    page = HTTParty.get(@next_link)
    parse_page = Nokogiri::HTML(page)
    @next_link = @domain + parse_page.at_css('#pagnNextLink')&.attribute('href')&.value
    while @next_link.nil? do
      sleep 3
      page = HTTParty.get(@next_link)
      parse_page = Nokogiri::HTML(page)
      @next_link = @domain + parse_page.at_css('#pagnNextLink')&.attribute('href')&.value
    end
    search_results = parse_page.css('div#resultsCol > div#centerMinus > div#atfResults > ul > li')
    search_results.each do |result|
      @product_links << result.at_css('div > div > div > div[2] > div[2] > div[1] > a').attribute('href').value.split('#').first
    end
  end

  def product_data(link)
    product_page = HTTParty.get(link)
    parse_product_page = Nokogiri::HTML(product_page)
    product_title = parse_product_page.at_css('#productTitle')&.text
    while product_title.nil? do
      sleep 3
      product_page = HTTParty.get(link)
      parse_product_page = Nokogiri::HTML(product_page)
      product_title = parse_product_page.at_css('#productTitle')&.text
    end
    product_author = parse_product_page.at_css('#byline > span > span.a-declarative > a.a-link-normal.contributorNameID')&.text
    product_author = parse_product_page.at_css('#byline > span')&.text&.tr("\n\t",'')&.gsub(/\s+/, " ")&.strip if product_author.nil?
    product_image_link = parse_product_page.at_css('#imgBlkFront')&.attribute('src')&.value
    product_content = parse_product_page.at_css('div#bookDescription_feature_div > noscript > div')&.to_html&.tr("\n\t",'')
    [product_title, product_author, product_image_link, product_content]
  end

  def csv_writer
    products_csv = CSV.open('products.csv', 'w', col_sep: '|')
    @product_links.each do |link|
      products_csv << product_data(link)
    end
    products_csv.close
  end
end

start_time = Time.now
KoahScraper.new(4).call
end_time = Time.now
running_time = end_time - start_time
puts "Running time: #{running_time} seconds"
