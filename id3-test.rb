#!/usr/bin/env ruby

#######################################################################
# id3-test.rb - test suite for ID3-Ruby                               #
# by Paul Duncan <pabs@pablotron.org>                                 #
#######################################################################

# load ID3 module
require 'id3'

ARGV.each { |path| 
  # load ID3 tag for given file
  id3 = ID3::new(path)

  # dump information about file to stdout
  puts [id3.year, id3.artist, id3.album, id3.track, id3.title,
        id3.comment, id3.genre, id3.version.to_s].join(',')
  
  # # ID3v2{3,4} frame descriptions
  # if id3.version[0] == 2 && id3.frames
  #   id3.frames.each { |frame|
  #     puts "#{frame.key}: #{id3.describe_frame(frame)}"
  #   }
  # end
  #
}
