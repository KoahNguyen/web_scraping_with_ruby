require 'open-uri'
require 'nokogiri'
require 'pry'

page = Nokogiri::HTML(open('http://www.nokogiri.org/tutorials/installing_nokogiri.html'))
puts page.class
Pry.start(binding)
