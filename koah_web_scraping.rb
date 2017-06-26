require 'httparty'
require 'nokogiri'
require 'pry'
require 'csv'

domain = 'https://www.amazon.com'
url = domain + '/s/ref=nb_sb_noss?url=node%3D3952&field-keywords='
page = HTTParty.get(url)
parse_page = Nokogiri::HTML(page)

next_link = domain + parse_page.at_css('#pagnNextLink').attribute('href').value

search_results = parse_page.css('div#search-results > div#mainResults > ul > li')
product_links = []
search_results.each do |result|
  product_links << result.at_css('div > div > div > div[2] > div[2] > div[1] > a').attribute('href').value.split('#').first
end

product_link = product_links[0]
product_page = HTTParty.get(product_link)
parse_product_page = Nokogiri::HTML(product_page)
product_title = parse_product_page.at_css('#productTitle').text
product_author = parse_product_page.at_css('#byline > span > span.a-declarative > a.a-link-normal.contributorNameID').text
product_image_link = parse_product_page.at_css('#imgBlkFront').attribute('src').value
product_content = parse_product_page.at_css('div#bookDescription_feature_div > noscript > div').to_html.tr("\n\t",'')
result = [product_title, product_author, product_image_link, product_content]

products_csv = CSV.open('products.csv', 'w', col_sep: '|')
products_csv << result
products_csv.close

# Pry.start(binding)
