#!/usr/bin/env ruby

require 'id3'

id3 = ID3::new('file.mp3')
puts "Artist: #{id3.artist}, Title: #{id3.title}, Track: #{id3.track}"

