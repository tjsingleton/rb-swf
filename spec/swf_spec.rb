require 'pathname'
require 'bindata'
require 'zlib'

module SWF
  class Scanner
    def initialize(io)
      @io = io
    end

    def scan
      @header = Header.read(@io)
      uncompressed_data = case @header.signature.compression_format
        when "F" then @io.read
        when "C" then Zlib::Inflate.inflate(@io.read)
        when "Z" then raise "LZMA compression not supported"
        else
          raise "Unknown compression format"
      end

      @frame_size = Rect.read(uncompressed_data)
    end

    attr_reader :header, :frame_size
  end

  class Signature < BinData::Record
    string :compression_format, length: 1
    string :w, length: 1
    string :s, length: 1

    def to_s
      "#{compression_format}#{w}#{s}"
    end
  end

  class Rect < BinData::Record
    endian :big

    bit5 :bit_length
    sbit :xmin, :nbits => :bit_length
    sbit :xmax, :nbits => :bit_length
    sbit :ymin, :nbits => :bit_length
    sbit :ymax, :nbits => :bit_length
  end

  class Header < BinData::Record
    endian :little
    signature :signature
    uint8 :version # ex: 0x06 = SWF 6
    uint32le :file_length
  end
end

describe SWF::Scanner do

  FIXTURE_PATH = Pathname.new(__dir__).join('fixtures').expand_path

  # [HEADER]        File version: 11
  # [HEADER]        File is zlib compressed. Ratio: 75%
  # [HEADER]        File size: 12794
  # [HEADER]        Frame rate: 24.000000
  # [HEADER]        Frame count: 285
  # [HEADER]        Movie width: 160.00
  # [HEADER]        Movie height: 290.00
  let(:file) { File.open(FIXTURE_PATH.join('signup.swf'), 'rb') }
  let(:scanner) { SWF::Scanner.new(file).tap(&:scan) }

  after { file.close }

  it "can read the signature" do
    signature = scanner.header.signature
    expect(signature.compression_format).to eq("C")
    expect(signature.w).to eq("W")
    expect(signature.s).to eq("S")
    expect(signature.to_s).to eq("CWS")
  end

  it "can read the version" do
    expect(scanner.header.version).to eq(11)
  end

  it "can read the file_length" do
    expect(scanner.header.file_length).to eq(12794)
  end

  it "can read the rectangle" do
    rect = scanner.frame_size
    expect(rect.xmin).to eq(0)
    expect(rect.ymin).to eq(0)
    expect(rect.xmax/20).to eq(160)
    expect(rect.ymax/20).to eq(290)
  end
end
