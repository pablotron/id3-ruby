#!/usr/bin/env ruby

class ID3
  attr_accessor :header, :version, :frames,
                :title, :track, :artist, :album, :year, :genre, :comment,
                :FRAME_DESCRIPTIONS

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

  @@GENRE_DESCRIPTIONS = [
    'Blues', # 0
    'Classic Rock', # 1
    'Country', # 2
    'Dance', # 3
    'Disco', # 4
    'Funk', # 5
    'Grunge', # 6
    'Hip-Hop', # 7
    'Jazz', # 8
    'Metal', # 9
    'New Age', # 10
    'Oldies', # 11
    'Other', # 12
    'Pop', # 13
    'R&B', # 14
    'Rap', # 15
    'Reggae', # 16
    'Rock', # 17
    'Techno', # 18
    'Industrial', # 19
    'Alternative', # 20
    'Ska', # 21
    'Death Metal', # 22
    'Pranks', # 23
    'Soundtrack', # 24
    'Euro-Techno', # 25
    'Ambient', # 26
    'Trip-Hop', # 27
    'Vocal', # 28
    'Jazz+Funk', # 29
    'Fusion', # 30
    'Trance', # 31
    'Classical', # 32
    'Instrumental', # 33
    'Acid', # 34
    'House', # 35
    'Game', # 36
    'Sound Clip', # 37
    'Gospel', # 38
    'Noise', # 39
    'AlternRock', # 40
    'Bass', # 41
    'Soul', # 42
    'Punk', # 43
    'Space', # 44
    'Meditative', # 45
    'Instrumental Pop', # 46
    'Instrumental Rock', # 47
    'Ethnic', # 48
    'Gothic', # 49
    'Darkwave', # 50
    'Techno-Industrial', # 51
    'Electronic', # 52
    'Pop-Folk', # 53
    'Eurodance', # 54
    'Dream', # 55
    'Southern Rock', # 56
    'Comedy', # 57
    'Cult', # 58
    'Gangsta', # 59
    'Top 40', # 60
    'Christian Rap', # 61
    'Pop/Funk', # 62
    'Jungle', # 63
    'Native American', # 64
    'Cabaret', # 65
    'New Wave', # 66
    'Psychadelic', # 67
    'Rave', # 68
    'Showtunes', # 69
    'Trailer', # 70
    'Lo-Fi', # 71
    'Tribal', # 72
    'Acid Punk', # 73
    'Acid Jazz', # 74
    'Polka', # 75
    'Retro', # 76
    'Musical', # 77
    'Rock & Roll', # 78
    'Hard Rock', # 79

     # Winamp extensions
    'Folk', # 80
    'Folk-Rock', # 81
    'National Folk', # 82
    'Swing', # 83
    'Fast Fusion', # 84
    'Bebob', # 85
    'Latin', # 86
    'Revival', # 87
    'Celtic', # 88
    'Bluegrass', # 89
    'Avantgarde', # 90
    'Gothic Rock', # 91
    'Progressive Rock', # 92
    'Psychedelic Rock', # 93
    'Symphonic Rock', # 94
    'Slow Rock', # 95
    'Big Band', # 96
    'Chorus', # 97
    'Easy Listening', # 98
    'Acoustic', # 99
    'Humour', # 100
    'Speech', # 101
    'Chanson', # 102
    'Opera', # 103
    'Chamber Music', # 104
    'Sonata', # 105
    'Symphony', # 106
    'Booty Bass', # 107
    'Primus', # 108
    'Porn Groove', # 109
    'Satire', # 110
    'Slow Jam', # 111
    'Club', # 112
    'Tango', # 113
    'Samba', # 114
    'Folklore', # 115
    'Ballad', # 116
    'Power Ballad', # 117
    'Rhythmic Soul', # 118
    'Freestyle', # 119
    'Duet', # 120
    'Punk Rock', # 121
    'Drum Solo', # 122
    'Acapella', # 123
    'Euro-House', # 124
    'Dance Hall', # 125
  ]

  #
  # User-readable frame description.
  #
  def parse_genre(id)
    if id.is_a? Fixnum
      @@GENRE_DESCRIPTIONS[id]
    else 
      case id
      when /^\((\d+)\)(.*)$/
        id, sub_genre = $1, $2
        @@GENRE_DESCRIPTIONS[id.to_i] + sub_genre
      when /^\d+$/
        @@GENRE_DESCRIPTIONS[id.to_i].dup
      else
        nil
      end
    end
  end




  #
  # frames keys to pre-parse, and what to assign them to
  #
  @@COMMON_ID3V23_FRAMES = {
    'COMM' => proc { |obj, val| obj.comment = val },
    'TALB' => proc { |obj, val| obj.album   = val },
    'TCON' => proc { |obj, val| obj.genre   = obj.parse_genre(val) },
    'TIT2' => proc { |obj, val| obj.title   = val },
    'TPE1' => proc { |obj, val| obj.artist  = val },
    'TRCK' => proc { |obj, val| obj.track   = val },
    'TYER' => proc { |obj, val| obj.year    = val },
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
    @@COMMON_ID3V23_FRAMES[frame.key].call(self, ary[-1])
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
        # if it's a text frame, then instantiate a text frame
        if ary[0] =~ /^T/
          ret << TextFrame.new(ary[0], ary[1], ary[2], frame)
        else
          ret << Frame.new(ary[0], ary[1], ary[2], frame)
        end

        # if it's a common frame, then pre-parse it
        if @@COMMON_ID3V23_FRAMES.keys.include?(ary[0])
          parse_common_id3v23_frame ret[-1] 
        end
      end
    end

    ret
  end

  def read_id3v22_frames(io)
    raise "TODO: ID3v22 frame support"
  end

  #
  # Read and parse ID3v2 frames.
  #
  def read_frames(io)
    if @header.version[0] == 2
      ret = if @header.version[1] == 2
        read_id3v22_frames(io)
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

    io = File::open(io, 'r') if io.is_a? String

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
        @genre = parse_genre(header.genre)
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

  #
  # id3v2{3,4} frame descriptions
  #
  @@ID3V23_FRAME_DESCRIPTIONS = {
    'AENC' => 'Audio encryption',
    'APIC' => 'Attached picture',

    'COMM' => 'Comments',
    'COMR' => 'Commercial frame',

    'ENCR' => 'Encryption method registration',
    'EQUA' => 'Equalization',
    'ETCO' => 'Event timing codes',

    'GEOB' => 'General encapsulated object',
    'GRID' => 'Group identification registration',

    'IPLS' => 'Involved people list',

    'LINK' => 'Linked information',

    'MCDI' => 'Music CD identifier',
    'MLLT' => 'MPEG location lookup table',

    'OWNE' => 'Ownership frame',

    'PRIV' => 'Private frame',
    'PCNT' => 'Play counter',
    'POPM' => 'Popularimeter',
    'POSS' => 'Position synchronisation frame',

    'RBUF' => 'Recommended buffer size',
    'RVAD' => 'Relative volume adjustment',
    'RVRB' => 'Reverb',

    'SYLT' => 'Synchronized lyric/text',
    'SYTC' => 'Synchronized tempo codes',

    'TALB' => 'Album/Movie/Show title',
    'TBPM' => 'BPM (beats per minute)',
    'TCOM' => 'Composer',
    'TCON' => 'Content type',
    'TCOP' => 'Copyright message',
    'TDAT' => 'Date',
    'TDLY' => 'Playlist delay',
    'TENC' => 'Encoded by',
    'TEXT' => 'Lyricist/Text writer',
    'TFLT' => 'File type',
    'TIME' => 'Time',
    'TIT1' => 'Content group description',
    'TIT2' => 'Title/songname/content description',
    'TIT3' => 'Subtitle/Description refinement',
    'TKEY' => 'Initial key',
    'TLAN' => 'Language(s)',
    'TLEN' => 'Length',
    'TMED' => 'Media type',
    'TOAL' => 'Original album/movie/show title',
    'TOFN' => 'Original filename',
    'TOLY' => 'Original lyricist(s)/text writer(s)',
    'TOPE' => 'Original artist(s)/performer(s)',
    'TORY' => 'Original release year',
    'TOWN' => 'File owner/licensee',
    'TPE1' => 'Lead performer(s)/Soloist(s)',
    'TPE2' => 'Band/orchestra/accompaniment',
    'TPE3' => 'Conductor/performer refinement',
    'TPE4' => 'Interpreted, remixed, or otherwise modified by',
    'TPOS' => 'Part of a set',
    'TPUB' => 'Publisher',
    'TRCK' => 'Track number/Position in set',
    'TRDA' => 'Recording dates',
    'TRSN' => 'Internet radio station name',
    'TRSO' => 'Internet radio station owner',
    'TSIZ' => 'Size',
    'TSRC' => 'ISRC (international standard recording code)',
    'TSSE' => 'Software/Hardware and settings used for encoding',
    'TYER' => 'Year',
    'TXXX' => 'User defined text information frame',

    'UFID' => 'Unique file identifier',
    'USER' => 'Terms of use',
    'USLT' => 'Unsychronized lyric/text transcription',

    'WCOM' => 'Commercial information',
    'WCOP' => 'Copyright/Legal information',
    'WOAF' => 'Official audio file webpage',
    'WOAR' => 'Official artist/performer webpage',
    'WOAS' => 'Official audio source webpage',
    'WORS' => 'Official internet radio station homepage',
    'WPAY' => 'Payment',
    'WPUB' => 'Publishers official webpage',
    'WXXX' => 'User defined URL link frame',
  }

  #
  # User-readable frame description.
  #
  def describe_frame(frame)
    if @version.major == 2 && [3, 4].include?(@version.minor)
      @@ID3V23_FRAME_DESCRIPTIONS[frame.key]
    elsif @version.major == 2 && @version.minor == 2
      raise "TODO: ID3v22 frame description support"
    elsif @versoin.major == 1
      raise "ID3v1 does not have frames."
    else
      raise "Unknown ID3 version."
    end
  end

end

if __FILE__ == $0
  ARGV.each { |path| 
    id3 = ID3::new(path)
    puts [id3.year, id3.artist, id3.album, id3.track, id3.title,
          id3.comment, id3.genre, id3.version.to_s].join(',')

# 
#     if id3.version[0] == 2 && id3.frames
#       id3.frames.each { |frame|
#         puts "#{frame.key}: #{id3.describe_frame(frame)}"
#       }
#     end
# 
  }
end
