#!/usr/bin/env ruby

class ID3
  attr_accessor :header, :version, :frames,
                :title, :track, :artist, :album, :year, :genre, :comment

  # options
  DEFAULT_INIT_OPTIONS = {
    :try_id3v1 => true,
  }

  # ID3v2 header, ID3v1 footer, and frame header
  Header = Struct.new :version, :flags, :size
  Footer = Struct.new :version, :flags, :size,
                      :title, :artist, :album, :year, :comment,
                      :track, :genre
  Frame = Struct.new :key, :size, :flags, :frame

  #
  # ID3 Version
  #
  class Version
    attr_accessor :major, :minor, :revision
    def initialize(*args)
      @major, @minor, @revision = args
    end

    def to_s
      [@major, @minor, @revision].join('.')
    end

    def [](i)
      [@major, @minor, @revision][i]
    end
  end

  class TextFrame
    attr_accessor :key, :size, :flags, :frame, :encoding, :text

    def initialize(*args)
      @key, @size, @flags, @frame = args
      @encoding, @text = args[-1].unpack('cA*')
    end
  end

  # 
  # Decode funky ID3 size encoding.
  # 
  def decode_size(len)
    (len & 0xef) | ((0xef00 & len) >> 1) |
    ((0xef0000 & len) >> 2) |((0xef000000 & len) >> 3)
  end

  #
  # Read and parse ID2v2 header.
  #
  def read_id3v2_header(io)
    ret = nil

    # look for / unpack initial ID3v2 header
    bytes = io.read 10
    ary = bytes.unpack('a3c3N')
    
    # check for ID3v2 header
    if ary[0] == 'ID3'
      # check ID3v2 header version
      raise "Unknown ID3v2 header version" if ary[1] < 2 || ary[1] > 4

      flags, size = ary[3], decode_size(ary[4])
      version = ID3::Version.new(2, ary[1], ary[2])

      # return header
      ret = Header.new(version, flags, size)
    end

    # return header
    ret
  end

  # 
  # Read and parse ID3v1 footer.
  #
  def read_id3v1_footer(io)
    ret = nil
    io.seek -128, IO::SEEK_END

    if bytes = io.read(128)
      ary = bytes.unpack('a3a30a30a30a4a29cc')
      if (ary[0] == 'TAG')
        ary.shift
        version = Version.new(1, ((ary[-2] == 0) ? 0 : 1), 0)
        ret = Footer.new(version, 0, 128, *ary)
      else
        raise "Missing ID3v1 footer"
      end
    else
      raise "Couldn't read from file"
    end

    ret
  end

  COMMON_ID3V23_FRAMES = {
    'TRCK' => proc { |obj, val| obj.track   = val },
    'TIT2' => proc { |obj, val| obj.title   = val },
    'TALB' => proc { |obj, val| obj.album   = val },
    'TPE1' => proc { |obj, val| obj.artist  = val },
    'TYER' => proc { |obj, val| obj.year    = val },
    'TCON' => proc { |obj, val| obj.genre   = val },
    'COMM' => proc { |obj, val| obj.comment = val },
  }

  #
  # Pre-parse common frames (title, artist, etc)
  #
  def parse_common_id3v23_frame(frame)
    case frame.key
    when /^T/
      ary = frame.encoding, frame.text
    when 'COMM'
      ary = frame.frame.unpack('ca3A*')
    end
    COMMON_ID3V23_FRAMES[frame.key].call(self, ary[-1])
  end

  #
  # Read and parse ID3v2{3,4} frames
  # 
  def read_id3v23_frames(io)
    ret = []
    start_pos = io.pos

    while io.pos - start_pos + 10 < @header.size
      # read frame header
      begin
        bytes = io.read(10)
      rescue 
        raise "Couldn't read ID3v2 frame: #$!"
      end

      # parse frame header
      ary = bytes.unpack('a4Nn')

      # read frame data
      if ary[1] > 0
        frame = io.read(ary[1])
        if ary[0] =~ /^T/
          ret << TextFrame.new(ary[0], ary[1], ary[2], frame)
        else
          ret << Frame.new(ary[0], ary[1], ary[2], frame)
        end

        # if it's a common frame, then pre-parse it
        if COMMON_ID3V23_FRAMES.keys.include?(ary[0])
          parse_common_id3v23_frame ret[-1] 
        end
      end
    end

    ret
  end

  #
  # Read and parse ID3v2 frames.
  #
  def read_frames(io)
    if @header.version[0] == 2
      ret = if @header.version[1] == 2
        raise "TODO: ID3v22 frame support"
      else
        read_id3v23_frames(io)
      end
    end

    ret
  end

  #
  # Initialize new ID3 instance.
  #  
  def initialize(io, opts = nil)
    # parse the ID3 header
    @header = nil
    @frames = nil
    opts ||= DEFAULT_INIT_OPTIONS

    begin
      if @header = read_id3v2_header(io)
        # TODO: read extended header
        @frames = read_frames(io)
      elsif opts[:try_id3v1]
        # we'll call it the header, even though it's a footer
        @header = read_id3v1_footer(io)

        # handle the common stuff
        @artist = header.artist
        @album = header.album
        @year = header.year
        @title = header.title
        @comment = header.comment
        @genre = header.genre
      else
        raise "Couldn't load ID3 header"
      end

      # set the version
      @version = header.version
    rescue 
      raise "Couldn't parse ID3 header: #$!"
    end
  end

  #
  # Return a hash of the ID3v2 frames (key => frame).
  #
  def to_hash
    ret = nil

    if @frames
      ret = {}
      @frames.each { |frame| ret[frame.key] = frame }
    end

    ret
  end
end

ARGV.each { |path| 
  File::open(path) { |fh|
    id3 = ID3.new(fh) 

    puts [id3.year, id3.artist, id3.album, id3.track, id3.title,
          id3.comment, id3.version.to_s].join(',')
  }
}
