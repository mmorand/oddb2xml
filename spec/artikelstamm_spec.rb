# encoding: utf-8

require 'spec_helper'
require "rexml/document"
require 'webmock/rspec'
include REXML
RUN_ALL = true

describe Oddb2xml::Builder do
  raise "Cannot rspec in directroy containing a spac" if / /.match(Oddb2xml::SpecData)
  NrExtendedArticles = 34
  NrSubstances = 14
  NrLimitations = 5
  NrInteractions = 5
  NrCodes = 5
  NrProdno = 23
  NrPackages = 24
  NrProducts = 19
  RegExpDesitin = /1125819012LEVETIRACETAM DESITIN Mini Filmtab 250 mg 30 Stk/
  include ServerMockHelper
  def check_artikelstamm_xml(key, expected_value)
    expect(@artikelstamm_name).not_to be nil
    expect(@inhalt).not_to be nil
    unless @inhalt.index(expected_value)
      puts expected_value
    end
    # binding.pry unless @inhalt.index(expected_value)
    expect(@inhalt.index(expected_value)).not_to be nil
  end
  def common_run_init(options = {})
    @savedDir = Dir.pwd
    @oddb2xml_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb2xml.xsd'))
    @oddb_calc_xsd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'oddb_calc.xsd'))
    @elexis_v5_xsd = File.expand_path(File.join(__FILE__, '..', '..', 'Elexis_Artikelstamm_v5.xsd'))
    @elexis_v5_csv = File.join(Oddb2xml::WorkDir, "artikelstamm_#{Date.today.strftime('%d%m%Y')}_v5.csv")

    expect(File.exist?(@oddb2xml_xsd)).to eq true
    expect(File.exist?(@oddb_calc_xsd)).to eq true
    expect(File.exist?(@elexis_v5_xsd)).to eq true
    cleanup_directories_before_run
    FileUtils.makedirs(Oddb2xml::WorkDir)
    Dir.chdir(Oddb2xml::WorkDir)
    mock_downloads
  end

  after(:all) do
    Dir.chdir @savedDir if @savedDir and File.directory?(@savedDir)
  end
  context 'when artikelstamm option is given' do
    before(:all) do
      common_run_init
      options = Oddb2xml::Options.parse(['--artikelstamm']) # , '--log'])
      # @res = buildr_capture(:stdout){ Oddb2xml::Cli.new(options).run }
      Oddb2xml::Cli.new(options).run # to debug
      @artikelstamm_name = File.join(Oddb2xml::WorkDir, "artikelstamm_#{Date.today.strftime('%d%m%Y')}_v5.xml")
      @doc = Nokogiri::XML(File.open(@artikelstamm_name))
      # @rexml = REXML::Document.new File.read(@artikelstamm_name)
      @inhalt = IO.read(@artikelstamm_name)
    end

    it 'should exist' do
      expect(File.exists?(@artikelstamm_name)).to eq true
    end

    it 'should create transfer.ut8' do
      expect(File.exists?(File.join(Oddb2xml::Downloads, 'transfer.utf8'))).to eq true
    end

    it 'should have a comment' do
      expect(@inhalt).to match /<!--Produced by/
    end

    it 'should have a GTIN and a public price with 14 chars (ean14)' do
      expected = %(<ITEM PHARMATYPE="N">
            <GTIN>68711428066649</GTIN>
            <PHAR>5863450</PHAR>
            <SALECD>A</SALECD>
            <DSCR>3M MEDIPORE+PAD Absorbtionsverb 10x15cm 8 x 25 Stk</DSCR>
            <DSCRF>3M MEDIPORE+PAD compr absorb 10x15cm 8 x 25 pce</DSCRF>
            <COMP>
                <GLN>7610182000007</GLN>
            </COMP>
            <PEXF>108.01</PEXF>
            <PPUB>178.20</PPUB>
        </ITEM>)
      expect(@inhalt.index(expected)).not_to be nil
    end

    it 'should have a ATC for product PRIORIX TETRA' do
      expected = %(<PRODUCT>
            <PRODNO>5815801</PRODNO>
            <SALECD>A</SALECD>
            <DSCR>PRIORIX TETRA Trockensub c Solv Fertspr</DSCR>
            <DSCRF>Priorix-Tetra, Pulver und Lösungsmittel zur Herstellung einer Injektionslösung</DSCRF>
            <ATC>J07BD54</ATC>
        </PRODUCT>)
      expect(@inhalt.index(expected)).not_to be nil
    end

    it 'should produce a Elexis_Artikelstamm_v5.csv' do
      expect(File.exists?(@elexis_v5_csv)).to eq true
      inhalt = File.open(@elexis_v5_csv, 'r+').read
      expect(inhalt.size).to be > 0
      expect(inhalt).to match /7680284860144/
    end

    it 'should NOT generate a v3 nonpharma xml' do
      v3_name = @artikelstamm_name.sub('_v5.xml', '_v3.xml').sub('artikelstamm_', 'artikelstamm_N_')
      expect(File.exist?(v3_name)).to eq false
    end

    it 'should NOT generate a vx pharma xml' do
      v3_name = @artikelstamm_name.sub('_v5.xml', '_v3.xml').sub('artikelstamm_', 'artikelstamm_P_')
      expect(File.exist?(v3_name)).to eq false
    end

    it 'should contain a LIMITATION_PTS' do
      expect(@inhalt.index('<LIMITATION_PTS>40</LIMITATION_PTS>')).not_to be nil
    end

    it 'should find price from Preparations.xml by setting' do
      expect(File.exists?(@elexis_v5_csv)).to eq true
      inhalt = File.open(@elexis_v5_csv, 'r+').read
      expected = %(7680658560014,Dibase 10'000 Tropfen 10000 IE/ml Fl 10 ml,,Flasche(n),5,9.25,,,,"",,SL)
      expect(inhalt.index(expected)).to be > 0
    end

    it 'should contain a PRODUCT which was not in refdata' do
      expected = %(<PRODUCT>
            <PRODNO>5559401</PRODNO>
            <SALECD>A</SALECD>
            <DSCR>Nutriflex Lipid plus, Infusionsemulsion, 1250ml</DSCR>
            <DSCRF/>
            <ATC>B05BA10</ATC>
        </PRODUCT>)
      expect(@inhalt.index(expected)).not_to be nil
    end

    it 'should have a price for Lynparza' do
      expect(File.exists?(@elexis_v5_csv)).to eq true
      inhalt = File.open(@elexis_v5_csv, 'r+').read
      expect(inhalt.index('7680651600014,Lynparza Kaps 50 mg 448 Stk,,Kapsel(n),5562.48,5947.55,,,,"",,SL')).not_to be nil
    end
    it 'should trim the ean13 to 13 length' do
      gtin14 = "00040565124346"
      expect(gtin14.length).to eq 14
      expected14 = %(<GTIN>#{gtin14}</GTIN>)
      expect(@inhalt.index(expected14)).to be nil
      gtin13 = gtin14[1..-1]
      expect(gtin13.length).to eq 13
      expected13 = %(<GTIN>#{gtin13}</GTIN>)
      expect(@inhalt.index(expected13)).not_to be nil
    end

    it 'should not contain a GTIN=0' do
      expect(@inhalt.index('GTIN>0</GTIN')).to be nil
    end

    it 'should contain a GTIN starting 0' do
      expect(@inhalt.index('GTIN>0')).to be > 0
    end

    it 'should contain a PHAR 4236857 from refdata_NonPharma.xml' do
      expect(@inhalt.index('<PHAR>4236863</PHAR>')).to be > 0
      # Marco leaves the 14 GTIN digit in previous importes. As of January 2018 force it to the 13 digits
      expect(@inhalt.index('<GTIN>0040565124346</GTIN>')).to be > 0
    end

    it 'should a DSCRF for 4042809018288 TENSOPLAST Kompressionsbinde 5cmx4.5m' do
      skip("Where does the DSCR for 4042809018288 come from. It should be TENSOPLAST bande compression 5cmx4.5m")
    end

    it 'should NOT add GTIN 7680172330414 SELSUN and ean13 start with 7680 (Swissmedic) which is marked as inactive in transfer.dat' do
      @inhalt = IO.read(@artikelstamm_name)
      expect(@inhalt.index('7680172330414')).to be nil
    end

    it 'should add GTIN 3605520301605 Armani Attitude which is marked as inactive in transfer.dat' do
      @inhalt = IO.read(@artikelstamm_name)
      expect(@inhalt.index('3605520301605')).not_to be nil
    end

    it 'should add BIOMARIS Voll Meersalz which is marked as inactive in transfer.dat but has PPUB and PEXF' do
      @inhalt = IO.read(@artikelstamm_name)
      expect(@inhalt.index('BIOMARIS Voll Meersalz 500 g')).not_to be nil
    end
    
    it 'Should not contain PHAR 8809544 Sildenavil with pexf and ppub 0.0' do
#1128809544Sildenafil Suspension 7mg/ml 100ml                0030850045801000000000000000000000002
      @inhalt = IO.read(@artikelstamm_name)
      expected = %(<ITEM PHARMATYPE="N">
            <GTIN>9999998809544</GTIN>
            <PHAR>8809544</PHAR>
            <SALECD>A</SALECD>
            <DSCR>Sildenafil Suspension 7mg/ml 100ml</DSCR>
            <DSCRF>--missing--</DSCRF>
            <PEXF>30.85</PEXF>
            <PPUB>45.80</PPUB>
        </ITEM>)
      expect(@inhalt.index(expected)).to be nil
    end

    it 'should a company EAN for 4042809018288 TENSOPLAST Kompressionsbinde 5cmx4.5m' do
      skip("Where does the COMP GLN for 4042809018288 come from. It should be 7601003468441")
    end

    it 'shoud contain Lamivudinum as 3TC substance' do
      expect(@inhalt.index('<SUBSTANCE>Lamivudinum</SUBSTANCE>')).not_to be nil
    end

    it 'shoud contain GENERIC_TYPE' do
      expect(@inhalt.index('<GENERIC_TYPE')).not_to be nil
    end
    
    it 'should contain DIBASE with phar' do
      expected = %(<ITEM PHARMATYPE="P">
            <GTIN>7680658570013</GTIN>
            <!--override  with-->
            <SALECD>A</SALECD>
            <DSCR>DIBASE 25'000, Lösung zum Einnehmen</DSCR>
            <DSCRF>--missing--</DSCRF>
            <COMP>
                <NAME>Gebro Pharma AG</NAME>
                <GLN/>
            </COMP>
            <PKG_SIZE>1</PKG_SIZE>
            <MEASURE>Flasche(n)</MEASURE>
            <MEASUREF>Flasche(n)</MEASUREF>
            <DOSAGE_FORM>Lösung</DOSAGE_FORM>
            <DOSAGE_FORMF>Solution</DOSAGE_FORMF>
            <IKSCAT>D</IKSCAT>
            <PRODNO>6585701</PRODNO>
        </ITEM>)
      expect(@inhalt.index(expected)).not_to be nil
    end
    
    it 'should contain PEVISONE Creme 30 g' do
      expect(@inhalt.index('Pevisone Creme 15 g')).not_to be nil # 7680406620144
      expect(@inhalt.index('Pevisone Creme 30 g')).not_to be nil # 7680406620229
      # Should also check for price!
    end
    it 'should validate against artikelstamm.xsd' do
      validate_via_xsd(@elexis_v5_xsd, @artikelstamm_name)
    end
      tests = { 'item 7680403330459 CARBADERM only in Preparations(SL) with public price' =>
        %(<ITEM PHARMATYPE="P">
            <GTIN>7680403330459</GTIN>
            <PHAR>3603779</PHAR>
            <SALECD>A</SALECD>
            <DSCR>Carbaderm Creme Tb 300 ml</DSCR>
            <DSCRF>Carbaderm crème tb 300 ml</DSCRF>
            <PEXF>14.61</PEXF>
            <PPUB>26.95</PPUB>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>D</IKSCAT>
            <DEDUCTIBLE>10</DEDUCTIBLE>
        </ITEM>),
        'item 4042809018288 TENSOPLAST' =>
      %(<ITEM PHARMATYPE="N">
            <GTIN>4042809018288</GTIN>
            <PHAR>0055805</PHAR>
            <SALECD>A</SALECD>
            <DSCR>TENSOPLAST Kompressionsbinde 5cmx4.5m</DSCR>
            <DSCRF>--missing--</DSCRF>
            <PEXF>0.00</PEXF>
            <PPUB>22.95</PPUB>
        </ITEM>),
         'product 3247501 LANSOYL' => '<ITEM PHARMATYPE="P">
            <GTIN>7680324750190</GTIN>
            <PHAR>0023722</PHAR>
            <SALECD>A</SALECD>
            <DSCR>LANSOYL Gel 225 g</DSCR>
            <DSCRF>LANSOYL gel 225 g</DSCRF>
            <COMP>
                <NAME>Actipharm SA</NAME>
                <GLN>7601001002012</GLN>
            </COMP>
            <PKG_SIZE>225</PKG_SIZE>
            <MEASURE>g</MEASURE>
            <MEASUREF>g</MEASUREF>
            <DOSAGE_FORM>Gelée</DOSAGE_FORM>
            <IKSCAT>D</IKSCAT>
            <LPPV>true</LPPV>
            <PRODNO>3247501</PRODNO>
        </ITEM>',
        'product 5366201 3TC' =>
      %(<ITEM PHARMATYPE="P">
            <GTIN>7680536620137</GTIN>
            <PHAR>1699947</PHAR>
            <SALECD>A</SALECD>
            <DSCR>3TC Filmtabl 150 mg 60 Stk</DSCR>
            <DSCRF>3TC cpr pell 150 mg 60 pce</DSCRF>
            <COMP>
                <NAME>ViiV Healthcare GmbH</NAME>
                <GLN>7601001392175</GLN>
            </COMP>
            <PEXF>164.55</PEXF>
            <PPUB>205.3</PPUB>
            <PKG_SIZE>60</PKG_SIZE>
            <MEASURE>Tablette(n)</MEASURE>
            <MEASUREF>Tablette(n)</MEASUREF>
            <DOSAGE_FORM>Filmtabletten</DOSAGE_FORM>
            <DOSAGE_FORMF>Comprimés filmés</DOSAGE_FORMF>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>A</IKSCAT>
            <GENERIC_TYPE>O</GENERIC_TYPE>
            <DEDUCTIBLE>10</DEDUCTIBLE>
            <PRODNO>5366201</PRODNO>
        </ITEM>),
        'item 7680161050583 HIRUDOID 40g' =>
         %(<ITEM PHARMATYPE="P">
            <GTIN>7680161050583</GTIN>
            <PHAR>2731179</PHAR>
            <SALECD>A</SALECD>
            <DSCR>Hirudoid Creme 3 mg/g 40 g</DSCR>
            <DSCRF>Hirudoid crème 3 mg/g 40 g</DSCRF>
            <COMP>
                <NAME>Medinova AG</NAME>
                <GLN>7601001002258</GLN>
            </COMP>
            <PEXF>4.768575</PEXF>
            <PPUB>8.8</PPUB>
            <PKG_SIZE>40</PKG_SIZE>
            <MEASURE>g</MEASURE>
            <MEASUREF>g</MEASUREF>
            <DOSAGE_FORM>Creme</DOSAGE_FORM>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>D</IKSCAT>
            <DEDUCTIBLE>10</DEDUCTIBLE>
            <PRODNO>1610501</PRODNO>
        </ITEM>),
        'item 7680161050743 100g ' => 
              %( <ITEM PHARMATYPE="P">
            <GTIN>7680161050743</GTIN>
            <PHAR>2731179</PHAR>
            <SALECD>A</SALECD>
            <DSCR>Hirudoid Creme 3 mg/g 100 g</DSCR>
            <DSCRF>Hirudoid crème 3 mg/g 100 g</DSCRF>
            <COMP>
                <NAME>Medinova AG</NAME>
                <GLN>7601001002258</GLN>
            </COMP>
            <PEXF>9.555316</PEXF>
            <PPUB>17.65</PPUB>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>D</IKSCAT>
            <DEDUCTIBLE>10</DEDUCTIBLE>
        </ITEM>), 
        'item 7680284860144 ANCOPIR' =>'<ITEM PHARMATYPE="P">
            <GTIN>7680284860144</GTIN>
            <PHAR>0177804</PHAR>
            <SALECD>A</SALECD>
            <DSCR>ANCOPIR Inj Lös 5 Amp 2 ml</DSCR>
            <DSCRF>Ancopir, sol inj</DSCRF>
            <COMP>
                <NAME>Dr. Grossmann AG, Pharmaca</NAME>
                <GLN/>
            </COMP>
            <PEXF>3.89</PEXF>
            <PPUB>8.55</PPUB>
            <PKG_SIZE>5</PKG_SIZE>
            <MEASURE>Ampulle(n)</MEASURE>
            <MEASUREF>Ampulle(n)</MEASUREF>
            <DOSAGE_FORM>Injektionslösung</DOSAGE_FORM>
            <DOSAGE_FORMF>Solution injectable</DOSAGE_FORMF>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>B</IKSCAT>
            <DEDUCTIBLE>10</DEDUCTIBLE>
            <PRODNO>2848601</PRODNO>
        </ITEM>',
                'FERRO-GRADUMET price from ZurRose  ' => %(<ITEM PHARMATYPE="P">
            <GTIN>7680316440115</GTIN>
            <PHAR>0020244</PHAR>
            <SALECD>A</SALECD>
            <DSCR>FERRO-GRADUMET Depottabl 30 Stk</DSCR>
            <DSCRF>FERRO-GRADUMET cpr dépôt 30 pce</DSCRF>
            <COMP>
                <NAME>Farmaceutica Teofarma Suisse SA</NAME>
                <GLN>7601001374539</GLN>
            </COMP>
            <PEXF>8.96</PEXF>
            <PPUB>13.80</PPUB>
            <PKG_SIZE>30</PKG_SIZE>
            <MEASURE>Tablette(n)</MEASURE>
            <MEASUREF>Tablette(n)</MEASUREF>
            <DOSAGE_FORM>Tupfer</DOSAGE_FORM>
            <DOSAGE_FORMF>Compresse</DOSAGE_FORMF>
            <IKSCAT>C</IKSCAT>
            <PRODNO>3164402</PRODNO>
        </ITEM>), 
      'product 3TC Filmtabl' => %(<PRODUCT>
            <PRODNO>5366201</PRODNO>
            <SALECD>A</SALECD>
            <DSCR>3TC Filmtabl 150 mg</DSCR>
            <DSCRF>3TC cpr pell 150 mg</DSCRF>
            <ATC>J05AF05</ATC>
            <SUBSTANCE>Lamivudinum</SUBSTANCE>
        </PRODUCT>),
        'nur aus Packungen Coeur-Vaisseaux Sérocytol,' => %(<ITEM PHARMATYPE="P">
            <GTIN>7680002770014</GTIN>
            <PHAR>0361815</PHAR>
            <SALECD>A</SALECD>
            <DSCR>SEROCYTOL Herz-Gefässe Supp 3 Stk</DSCR>
            <DSCRF>SEROCYTOL Coeur-Vaisseaux supp 3 pce</DSCRF>
            <COMP>
                <NAME>Serolab SA (succursale de Remaufens)</NAME>
                <GLN>7640128710004</GLN>
            </COMP>
            <PKG_SIZE>3</PKG_SIZE>
            <MEASURE>Suppositorien</MEASURE>
            <MEASUREF>Suppositorien</MEASUREF>
            <DOSAGE_FORM>suppositoire</DOSAGE_FORM>
            <IKSCAT>B</IKSCAT>
            <PRODNO>0027701</PRODNO>
        </ITEM>),
        'HUMALOG (Richter)' => %(<ITEM PHARMATYPE="P">
            <GTIN>7680532900196</GTIN>
            <PHAR>1699999</PHAR>
            <SALECD>A</SALECD>
            <DSCR>Humalog Inj Lös Durchstf 10 ml</DSCR>
            <DSCRF>Humalog sol inj flac 10 ml</DSCRF>
            <COMP>
                <NAME>Eli Lilly (Suisse) SA</NAME>
                <GLN>7601001261853</GLN>
            </COMP>
            <PEXF>30.4</PEXF>
            <PPUB>51.3</PPUB>
            <PKG_SIZE>1</PKG_SIZE>
            <MEASURE>Flasche(n)</MEASURE>
            <MEASUREF>Flasche(n)</MEASUREF>
            <DOSAGE_FORM>Injektionslösung</DOSAGE_FORM>
            <DOSAGE_FORMF>Solution injectable</DOSAGE_FORMF>
            <SL_ENTRY>true</SL_ENTRY>
            <IKSCAT>B</IKSCAT>
            <DEDUCTIBLE>20</DEDUCTIBLE>
            <PRODNO>5329001</PRODNO>
        </ITEM>),
        'Chapter 70 limitation' => %(<LIMITATION>
            <!--Chapter70 hack-->
            <LIMNAMEBAG>L1, L2</LIMNAMEBAG>
            <DSCR>Eine Flasche zu 20 ml Urtinktur einer bestimmten Pflanze pro Monat. Für Aesculus, Carduus Marianus, Ginkgo, Hedera helix, Hypericum perforatum, Lavandula, Rosmarinus officinalis, Taraxacum officinale.</DSCR>
            <DSCRF/>
            <LIMITATION_PTS>1</LIMITATION_PTS>
        </LIMITATION>),
        'Chapter 70 product' => %(<PRODUCT>
            <PRODNO>2069639</PRODNO>
            <!--Chapter70 hack-->
            <SALECD>A</SALECD>
            <DSCR>Ceres Urtinkturen gemäss L2</DSCR>
            <DSCRF/>
            <LIMNAMEBAG>L1, L2</LIMNAMEBAG>
        </PRODUCT>),
        'Chapter 70 item' => %(<ITEM PHARMATYPE="P">
            <GTIN>2500000588532</GTIN>
            <PHAR>2069639</PHAR>
            <SALECD>A</SALECD>
            <DSCR>EINF ARZNEI Ceres Urtinktur spez 20ml</DSCR>
            <DSCRF>--missing--</DSCRF>
            <PEXF>23.44</PEXF>
            <PPUB>31.30</PPUB>
            <!--Chapter70 hack-->
            <SL_ENTRY>true</SL_ENTRY>
            <PRODNO>2069639</PRODNO>
        </ITEM>),
        'HTML-encoded limitation' => %(<DSCR>Zur Erhaltungstherapie (Monotherapie) bei erwachsenen Patientinnen mit rezidiviertem, fortgeschrittenem Ovarialkarzinom mit BRCA Mutation im Anschluss an eine platinhaltige Chemotherapie bei Vorliegen einer kompletten oder partiellen Remission.

Der behandelnde Arzt ist verpflichtet, die erforderlichen Daten laufend im vorgegebenen Internettool des Registers, abrufbar auf http://www.olaparib-registry.ch, zu erfassen. Eine schriftliche Einwilligung der Patientin muss vorliegen. Es sind folgende Daten zu erfassen:

1\)	Geburtsjahr, sowie Vortherapien für das OC

2\)	Datum Therapiestart, Dosierung, Dosisanpassungen, Datum Therapieende.
</DSCR>),
              }

      tests.each do |key, expected|
        it "should a valid entry for #{key}" do
          check_artikelstamm_xml(key, expected)
        end
      end
  end
  context 'chapter 70 hack' do
    before(:all) do
      mock_downloads
    end
    it 'parsing' do
      require 'oddb2xml/chapter_70_hack'
      result = Oddb2xml::Chapter70xtractor.parse()
      expect(result.class).to eq Array
      expect(result.first).to eq ["2069562", "70.01.10", "Urtinktur", "1--10 g/ml", "13.40", ""]
      expect(result.last).to eq  ["6516727", "70.02", "Allergenorum extractum varium / Inj. Susp. \tFortsetzungsbehandlung", "1 Durchstfl 1.5 ml", "311.85", "L"]
    end

  end
end
