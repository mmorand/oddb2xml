# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
#
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
$:.unshift File.dirname(__FILE__)

require 'rspec'
require 'webmock/rspec'
require 'flexmock/rspec'
require 'pp'

begin # load pry if is available
require 'pry'
Pry.config.output = STDOUT
rescue LoadError
end

require 'vcr'
require 'timecop'

module Oddb2xml
  # we override here a few directories to make input/output when running specs to
  # be in different places compared when running
  SpecData       = File.join(File.dirname(__FILE__), 'data')
  WorkDir        = File.join(File.dirname(__FILE__), 'run')
  Downloads      = File.join(WorkDir, 'downloads')
  SpecCompressor = File.join(Oddb2xml::SpecData, 'compressor')
  DATE_REGEXP    = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[-+]\d{4}/

  GTINS_CALC = [
                  '7680458820202', # for calc_spec.rb
                  '7680555940018', # for calc_spec.rb
                  '7680434541015', # for calc_spec.rb
                  '7680300150105', # for calc_spec.rb
                  '7680446250592', # for calc_spec.rb
                  '7680611860045', # for calc_spec.rb
                  '7680165980114', # for calc_spec.rb
                  '7680589430011', # for calc_spec.rb
                  '7680556740075', # for calc_spec.rb
                  '7680540151009', # for calc_spec.rb
                  '7680560890018', # for calc_spec.rb
                  '7680532900196', # Insulin, gentechnik
                  '7680555610041', # Diaphin 10 g i.v. drug
    ]
  FRIDGE_GTIN = '7680002770014'   # fridge drug 7680002770014 Coeur-Vaisseaux Sérocytol, suppositoire
  ORPHAN_GTIN = '7680587340015'   # orphan drug IKSNR 62132: Adcetris, Pulver zur Herstellung einer Infusionslösung
  GTINS_DRUGS = [ '733905577161', # 1-DAY ACUVUE Moist Tag -2.00dpt BC 8.5
                  FRIDGE_GTIN,
                  ORPHAN_GTIN,
                  '4042809018288',
                  '4042809018400',
                  '4042809018493',
                  '5000223074777',
                  '5000223439507',
                  '7611600441013',
                  '7611600441020',
                  '7611600441037',
                  '7680161050583', # Hirudoid Creme 3 mg/g
                  '7680172330414', # SELSUN
                  '7680284860144',
                  '7680316440115', # FERRO-GRADUMET Depottabl 30 Stk
                  '7680316950157', # SOFRADEX Gtt Auric 8 ml
                  '7680324750190', # LANSOYL Gel
                  '7680353660163',
                  '7680403330459',
                  '7680536620137', # 3TC Filmtabl 150 mg
                  '7680555580054', # ZYVOXID
                  '7680620690084', # LEVETIRACETAM DESITIN Mini Filmtab 250 mg needed for extractor_spec.rb
                  ] + GTINS_CALC
    FERRO_GRADUMET_GTIN           = '7680316440115'
    HIRUDOID_GTIN                 = '7680161050583'
    LANSOYL_GTIN                  = '7680324750190'
    LANSOYL_PRICE_RESELLER_PUB    = 18.95
    LANSOYL_PRICE_ZURROSE         = 10.54
    LANSOYL_PRICE_ZURROSEPUB      = 16.25
    LEVETIRACETAM_GTIN            = '7680620690084'
    LEVETIRACETAM_PRICE_PPUB      = 27.8
    LEVETIRACETAM_PRICE_ZURROSE   = 13.49
    LEVETIRACETAM_PRICE_RESELLER_PUB = 24.3
    SOFRADEX_GTIN                 = '7680316950157'
    SOFRADEX_PRICE_RESELLER_PUB   = 12.9
    SOFRADEX_PRICE_ZURROSE        = 7.18
    SOFRADEX_PRICE_ZURROSEPUB     = 15.45
    THREE_TC_GTIN                 = '7680536620137'
    ZYVOXID_GTIN                  = '7680555580054'

  GTINS_MEDREG = [
    '7601001380028', # Glarus
    '7601002017145', # Kantonsspital Glarus AG
    '7601001395145', # Kantonstierärztlicher Dienst
    '7601001396043', # St. Fridolin Pharma AG
    '7601000159199', #  Davatz  Ursula
    '7601000159199', #  Davatz  Ursula
    '7601000254344', #  Pfister Daniel  8753  Mollis
    '7601000254207', #  Züst  Peter 8753  Mollis
    '7601000752314', #  Züst  Yvonne  8753  Mollis
    ]

end

RSpec.configure do |config|
    config.mock_with :flexmock
  end        

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.debug_logger = File.open(File.join(File.dirname(File.dirname(__FILE__)), 'vcr.log'), 'w+')
  config.debug_logger.sync = true
  config.default_cassette_options = { :record =>:once, # ARGV.join(' ').index('downloader_spec') ? :new_episodes : :once ,
                                      :preserve_exact_body_bytes => true,
                                      :allow_playback_repeats => true,
                                      :serialize_with => :json,
                                      :decode_compressed_response => true,
                                      :match_requests_on => [:method, :uri, :body],
                                    }
#	 :match_requests_on (Array<Symbol, #call>) —
#
# List of request matchers to use to determine what recorded HTTP interaction to replay. Defaults to [:method, :uri]. The built-in matchers are :method, :uri, :host, :path, :headers and :body. You can also pass the name of a registered custom request matcher or any object that responds to #call.

  config.before_http_request(:real?) do |request|
    $stderr.puts("before real request: #{request.method} #{request.uri} #{caller[0..5].join("\n")}")
    $stderr.flush
  end
end

AllCompositionLines = File.expand_path("#{__FILE__}/../data/compositions.txt")
AllColumn_C_Lines = File.expand_path("#{__FILE__}/../data/column_c.txt")

require 'oddb2xml'

module Kernel
  def buildr_capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval "$#{stream} = #{stream.upcase}"
    end
    result
  end
end

module ServerMockHelper
  def cleanup_compressor
    [ File.join(Oddb2xml::SpecCompressor, '*.zip'),
      File.join(Oddb2xml::SpecCompressor, '*.tar.gz'),
      File.join(Oddb2xml::SpecCompressor, 'epha_interactions.txt*'),
      File.join(Oddb2xml::SpecCompressor, 'medregbm_company.txt*'),
      File.join(Oddb2xml::SpecCompressor, 'medregbm_person.txt*'),
      File.join(Oddb2xml::SpecCompressor, 'transfer.dat.*'),
      File.join(Oddb2xml::SpecCompressor, 'oddb2xml_files_nonpharma.xls.*'),
      ].each { |file| FileUtils.rm_f(Dir.glob(file), :verbose => false) if Dir.glob(file).size > 0 }
  end
  def cleanup_directories_before_run
    dirs = [ Oddb2xml::Downloads, Oddb2xml::WorkDir]
    dirs.each{ |dir| FileUtils.rm_rf(Dir.glob(File.join(dir, '*')), :verbose => false) }
    dirs.each{ |dir| FileUtils.makedirs(dir, :verbose => false) }
    cleanup_compressor
    mock_downloads
  end

  def setup_server_mocks
    puts "Skip setup_server_mocks as we want to use vcr"
  end
end

def check_elements(xml_name, tests)
  tests.each do |test|
    path = test[0]
    value = test[1]
    it "should have correct entries #{value} for path #{path}" do
      found = false
        Nokogiri::XML(File.read(xml_name)).search(path, nil, nil).each do |x|
        if value.match(x.text)
          found= true
          break
        end
      end
      expect(found).to be true
    end
  end
end

def check_attributes(xml_name, tests)
  tests.each do |test|
    path = test[0]
    attribute = test[1]
    value = test[2]
    it "should have correct value #{value} for attribute #{attribute} in #{path}" do
      found = false
      Nokogiri::XML(File.read(xml_name)).search(path, nil, nil).each do |x|
        if value.match(x["#{attribute}"])
          found= true
          break
        end
      end
      expect(found).to be true
    end
  end
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.filter_run_excluding :slow
  #config.exclusion_filter = {:slow => true}

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # Helper
  config.include(ServerMockHelper)
end

def validate_via_xsd(xsd_file, xml_file)
  xsd =open(xsd_file).read
  xsd_rtikelstamm_xml = Nokogiri::XML::Schema(xsd)
  doc = Nokogiri::XML(File.read(xml_file))
  xsd_rtikelstamm_xml.validate(doc).each do
    |error|
      if error.message
        puts "Failed validating #{xml_file} with #{File.size(xml_file)} bytes using XSD from #{xsd_file}"
        puts "CMD: xmllint --noout --schema #{xsd_file} #{xml_file}"
      end
      msg = "expected #{error.message} to be nil\nfor #{xml_file}"
      puts msg
      expect(error.message).to be_nil, msg
  end
end

def mock_downloads
    WebMock.enable!
    { 'transfer.zip' => ['transfer.dat'],
      'XMLPublications.zip' => ['Preparations.xml', 'ItCodes.xml', 'GL_Diff_SB.xml']
      }.each do |zip, entries|
        zip_file = File.join(Oddb2xml::SpecData,zip)
        files = entries.collect{|entry| File.join(Oddb2xml::SpecData, entry)}
        FileUtils.rm(zip_file, :verbose => false) if File.exist?(zip_file)
        cmd = "zip --quiet --junk-paths #{zip_file} #{files.join(' ')}"
        system(cmd)
    end
    { 'https://download.epha.ch/cleaned/matrix.csv' =>  'epha_interactions.csv',
      'https://www.swissmedic.ch/swissmedic/de/home/services/listen_neu.html' => 'listen_neu.html',
      'https://www.swissmedic.ch/dam/swissmedic/de/dokumente/internetlisten/status_ophan%20Drug.xlsx.download.xlsx/Liste_OrphanDrug_Internet_2019_01_31.xlsx' =>  'swissmedic_orphan.xlsx',
      'https://www.swissmedic.ch/dam/swissmedic/de/dokumente/internetlisten/zugelassene_packungen_ham.xlsx.download.xlsx/Zugelassene_Packungen%20HAM_31012019.xlsx' => 'swissmedic_package.xlsx',
      'http://pillbox.oddb.org/TRANSFER.ZIP' =>  'transfer.zip',
      'https://raw.githubusercontent.com/epha/robot/master/data/manual/swissmedic/atc.csv' => 'atc.csv',
      'https://raw.githubusercontent.com/zdavatz/oddb2xml_files/master/LPPV.txt' => 'oddb2xml_files_lppv.txt',
      'http://bag.e-mediat.net/SL2007.Web.External/File.axd?file=XMLPublications.zip' => 'XMLPublications.zip',
      'http://bag.e-mediat.net/Sl2007.web.external/varia_De.htm' => 'varia_De.htm',
#      'http://refdatabase.refdata.ch/Service/Article.asmx?WSDL' => 'refdata_Pharma.xml',
      }.each do |url, file|
      inhalt = File.read(File.join(Oddb2xml::SpecData, file))
      m = flexmock('open-uri')
      m.should_receive(:open).with(url).and_return(inhalt)
      stub_request(:any,url).to_return(body: inhalt)
      stub_request(:get,url).to_return(body: inhalt)
      stub_request(:open,url).to_return(body: inhalt)
    end
    VCR.eject_cassette; VCR.insert_cassette('oddb2xml')
end
