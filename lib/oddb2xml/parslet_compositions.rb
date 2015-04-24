# encoding: utf-8

# This file is shared since oddb2xml 2.0.0 (lib/oddb2xml/parse_compositions.rb)
# with oddb.org src/plugin/parse_compositions.rb
#
# It allows an easy parsing of the column P Zusammensetzung of the swissmedic packages.xlsx file
#

require 'parslet'
require 'parslet/convenience'
require 'oddb2xml/compositions_syntax'
include Parslet
VERBOSE_MESSAGES = false

module ParseUtil
  # this class is responsible to patch errors in swissmedic entries after
  # oddb.org detected them, as it takes sometimes a few days (or more) till they get corrected
  # Reports the number of occurrences of each entry
  class HandleSwissmedicErrors

    attr_accessor :nrParsingErrors
    class ErrorEntry   < Struct.new('ErrorEntry', :pattern, :replacement, :nr_occurrences)
    end

    def reset_errors
      @errors = []
      @nrLines = 0
      @nrParsingErrors = 0
    end

    # error_entries should be a hash of  pattern, replacement
    def initialize(error_entries)
      reset_errors
      error_entries.each{ |pattern, replacement| @errors << ErrorEntry.new(pattern, replacement, 0) }
    end

    def report
      s = ["Report of changed compositions in #{@nrLines} lines. Had #{@nrParsingErrors} parsing errors" ]
      @errors.each {
        |entry|
      s << "  replaced #{entry.nr_occurrences} times '#{entry.pattern}'  by '#{entry.replacement}'"
      }
      s
    end

    def apply_fixes(string)
      result = string.clone
      @errors.each{
        |entry|
        intermediate = result.clone
        result = result.gsub(entry.pattern,  entry.replacement)
        unless result.eql?(intermediate)
            entry.nr_occurrences += 1
            puts "Fixed #{result}" if VERBOSE_MESSAGES
        end
      }
      @nrLines += 1
      result
    end
    #  hepar sulfuris D6 2,2 mg hypericum perforatum D2 0,66 mg where itlacks a comma and should be hepar sulfuris D6 2,2 mg, hypericum perforatum D2 0,66 mg
  end

  def ParseUtil.capitalize(string)
    string.split(/\s+/u).collect { |word| word.capitalize }.join(' ').strip
  end

  def ParseUtil.parse_compositions(composition_text, active_agents_string = '')
    active_agents = active_agents_string ? active_agents_string.downcase.split(/,\s+/) : []
    comps = []
    lines = composition_text.gsub(/\r\n?/u, "\n").split(/\n/u)
    lines.select {
      |line|
      composition =  ParseComposition.from_string(line)
      if composition.is_a?(ParseComposition)
        composition.substances.each {
          |substance_item|
          substance_item.is_active_agent = (active_agents.find {|x| x.downcase.eql?(substance_item.name.downcase) } != nil)
          substance_item.is_active_agent = true if substance_item.chemical_substance and active_agents.find {|x| x.downcase.eql?(substance_item.chemical_substance.name.downcase) }
         }
        comps << composition
      end
    }
    comps << ParseComposition.new(composition_text.split(/,|:|\(/)[0]) if comps.size == 0
    comps
  end
end

class IntLit   < Struct.new(:int)
  def eval; int.to_i; end
end
class QtyLit   < Struct.new(:qty)
  def eval; qty.to_i; end
end

class CompositionTransformer < Parslet::Transform
  rule(:int => simple(:int))        { IntLit.new(int) }
  rule(:number => simple(:nb)) {
    nb.match(/[eE\.]/) ? Float(nb) : Integer(nb)
  }
  rule(
    :qty_range    => simple(:qty_range),
    :unit   => simple(:unit))  {
      ParseDose.new(qty_range, unit)
    }
  rule(
    :qty_range    => simple(:qty_range)) {
      ParseDose.new(qty_range)
    }
  rule(
    :qty    => simple(:qty),
    :unit   => simple(:unit))  {
      ParseDose.new(qty, unit)
    }
  rule(
    :unit    => simple(:unit))  { ParseDose.new(nil, unit) }
  rule(
    :qty    => simple(:qty))  { ParseDose.new(qty, nil) }

  @@substances ||= []
  @@excipiens  = nil
  def CompositionTransformer.clear_substances
    @@substances = []
    @@excipiens  = nil
    @@corresp    = nil
  end
  def CompositionTransformer.substances
    @@substances.clone
  end
  def CompositionTransformer.excipiens
    @@excipiens ? @@excipiens.clone : nil
  end
  def CompositionTransformer.corresp
    @@corresp ? @@corresp.clone : nil
  end

  rule(:ratio => simple(:ratio) ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@substances.last.more_info = dictionary[:ratio].to_s if @@substances.last
  }
  rule(:substance => sequence(:substance),
       :ratio => simple(:ratio)) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@substances.last.more_info = dictionary[:ratio].to_s if @@substances.last
  }

  rule(:solvens => simple(:solvens) ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance =  ParseSubstance.new(dictionary[:solvens].to_s)
      substance.more_info =  'Solvens'
      @@substances <<  substance
  }
  rule(:lebensmittel_zusatz => simple(:lebensmittel_zusatz),
       :more_info => simple(:more_info),
       :digits => simple(:digits)) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance =  ParseSubstance.new("#{dictionary[:lebensmittel_zusatz]} #{dictionary[:digits]}")
      substance.more_info =  dictionary[:more_info].to_s.sub(/:$/, '')
      @@substances <<  substance
  }
  rule(:lebensmittel_zusatz => simple(:lebensmittel_zusatz),
       :digits => simple(:digits)) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"  if VERBOSE_MESSAGES
      @@substances << ParseSubstance.new("#{dictionary[:lebensmittel_zusatz]} #{dictionary[:digits]}")
      dictionary[:substance]
  }
  rule(:substance => simple(:substance)) {
    |dictionary|
    puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
  }
  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
  }
  rule(:substance_ut => sequence(:substance_ut),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      nil
  }
  rule(:for_ut => sequence(:for_ut),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      if dictionary[:for_ut].size > 1
        @@substances[-2].salts << dictionary[:for_ut].last.clone
        @@substances.delete(dictionary[:for_ut].last)
      end
      nil
  }

  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       :substance_corresp => sequence(:substance_corresp),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      substance.chemical_substance = @@substances.last
      @@substances.delete_at(-1)
      @@substances <<  substance
  }

  rule(:mineralia => simple(:mineralia),
       :more_info => simple(:more_info),
       :substance_name => simple(:substance_name),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      substance.more_info = dictionary[:mineralia].to_s + ' ' + dictionary[:more_info].to_s
       # TODO: fix alia
      @@substances <<  substance
  }
  rule(:substance_name => simple(:substance_name),
       :conserv => simple(:conserv),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      substance = ParseSubstance.new(dictionary[:substance_name], ParseDose.new(dictionary[:dose].to_s))
      @@substances <<  substance
      substance.more_info =  dictionary[:conserv].to_s.sub(/:$/, '')
  }

  rule(:substance_name => simple(:substance_name),
       :mineralia => simple(:mineralia),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      substance = ParseSubstance.new(dictionary[:substance_name])
      substance.more_info =  dictionary[:mineralia].to_s.sub(/:$/, '')
      @@substances <<  substance
  }
  rule(:substance_name => simple(:substance_name),
       :more_info => simple(:more_info),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:substance_name])
      @@substances <<  substance
      substance.more_info =  dictionary[:more_info].to_s.sub(/:$/, '')
  }
  rule(:substance_name => simple(:substance_name),
       :residui => simple(:residui),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
       binding.pry
      substance = ParseSubstance.new(dictionary[:substance_name])
      @@substances <<  substance
      substance.more_info =  dictionary[:residui].to_s.sub(/:$/, '')
  }
  rule(:qty => simple(:qty),
       :unit => simple(:unit),
       :dose_right => simple(:dose_right),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      ParseDose.new(dictionary[:qty].to_s, dictionary[:unit].to_s + ' et ' +  dictionary[:dose_right].to_s )
  }

  rule(:substance_name => simple(:substance_name),
       :qty => simple(:qty),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s.strip, ParseDose.new(dictionary[:qty].to_s))
  }

  rule(:substance_name => simple(:substance_name),
       :dose_corresp => simple(:dose_corresp),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose_corresp])
  }
  rule(:description => simple(:description),
       :substance_name => simple(:substance_name),
       :qty => simple(:qty),
       :more_info => simple(:more_info),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:substance_name], ParseDose.new(dictionary[:qty].to_s))
      @@substances <<  substance
      substance.more_info =  dictionary[:more_info].to_s
      substance.description =  dictionary[:description].to_s
      substance
  }
  rule(:der => simple(:der),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@substances << ParseSubstance.new(dictionary[:der].to_s)
  }
  rule(:der => simple(:der),
       :substance_corresp => sequence(:substance_corresp),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      substance = ParseSubstance.new(dictionary[:der].to_s)
      substance.chemical_substance = @@substances.last
      @@substances.delete_at(-1)
      @@substances <<  substance
  }
  rule(:histamin => simple(:histamin),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: histamin dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:histamin].to_s)
  }
  rule(:substance_name => simple(:substance_name),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"  if VERBOSE_MESSAGES
      @@substances << ParseSubstance.new(dictionary[:substance_name].to_s)
  }
  rule(:one_substance => sequence(:one_substance)) {
    |dictionary|
       puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:one_substance])
  }
  rule(:one_substance => sequence(:one_substance)) {
    |dictionary|
       puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances << ParseSubstance.new(dictionary[:one_substance])
  }

  rule(:substance_name => simple(:substance_name),
       :substance_ut => sequence(:substance_ut),
       :dose => simple(:dose),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      @@substances.last.salts << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      nil
  }

  rule(:mineralia => simple(:mineralia),
       :dose => simple(:dose),
       :substance_name => simple(:substance_name),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"  if VERBOSE_MESSAGES
      dose = dictionary[:dose].is_a?(ParseDose) ? dictionary[:dose] : ParseDose.new(dictionary[:dose].to_s)
      substance = ParseSubstance.new(dictionary[:substance_name], dose)
      substance.more_info = dictionary[:mineralia].to_s
      @@substances <<  substance
      # @@substances << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
  }

  rule(:mineralia => simple(:mineralia),
       :dose => simple(:dose),
       :substance_ut => simple(:substance_ut),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
      dose = dictionary[:dose].is_a?(ParseDose) ? dictionary[:dose] : ParseDose.new(dictionary[:dose].to_s)
      substance = ParseSubstance.new(dictionary[:substance_ut], dose)
      substance.more_info = dictionary[:mineralia].to_s
       binding.pry
      @@substances <<  substance
      nil
  }


  rule(:mineralia => simple(:mineralia),
       :substance_ut => simple(:substance_ut),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}"
       binding.pry
      @@substances.last.salts << ParseSubstance.new(dictionary[:substance_name].to_s, dictionary[:dose])
      nil
  }
  rule( :more_info => simple(:more_info),
        :substance_name => simple(:substance_name),
        :dose => simple(:dose),
      ) {
    |dictionary|
        puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
        dose = dictionary[:dose].is_a?(ParseDose) ? dictionary[:dose] : ParseDose.new(dictionary[:dose].to_s)
        substance = ParseSubstance.new(dictionary[:substance_name], dose)
        substance.more_info = dictionary[:more_info].to_s
        @@substances <<  substance
  }

  rule(:excipiens => simple(:excipiens),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@excipiens = dictionary[:excipiens].is_a?(ParseDose) ? ParseSubstance.new('excipiens', dictionary[:excipiens]) : nil
  }

  rule(:substance_name => simple(:substance_name),
       :dose_pro => simple(:dose_pro),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      dose = dictionary[:dose_pro].is_a?(ParseDose) ? dictionary[:dose_pro] : ParseDose.new(dictionary[:dose_pro].to_s)
      substance = ParseSubstance.new(dictionary[:substance_name], dose)
      @@excipiens = dose
      @@substances <<  substance
  }
  rule(:substance_name => simple(:substance_name),
       :dose => simple(:dose),
       :dose_pro => simple(:dose_pro),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      dose = dictionary[:dose_pro].is_a?(ParseDose) ? dictionary[:dose_pro] : ParseDose.new(dictionary[:dose_pro].to_s)
      dose_pro = dictionary[:dose_pro].is_a?(ParseDose) ? dictionary[:dose_pro] : ParseDose.new(dictionary[:dose_pro].to_s)
      substance = ParseSubstance.new(dictionary[:substance_name], dose)
      @@excipiens = dose_pro
      @@substances <<  substance
  }

  rule(:dose_pro => simple(:dose_pro),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      dictionary[:dose_pro]
  }

  rule(:corresp => simple(:corresp),
       ) {
    |dictionary|
      puts "#{File.basename(__FILE__)}:#{__LINE__}: dictionary #{dictionary}" if VERBOSE_MESSAGES
      @@corresp = dictionary[:corresp].to_s
  }
end

class ParseDose
  attr_reader :qty, :qty_range
  attr_accessor :unit
  def initialize(qty=nil, unit=nil)
    puts "ParseDose.new from #{qty.inspect} #{unit.inspect} #{unit.inspect}" if VERBOSE_MESSAGES
    if qty and (qty.is_a?(String) || qty.is_a?(Parslet::Slice))
      string = qty.to_s.gsub("'", '')
      if string.index('-') and (string.index('-') > 0)
        @qty_range = string
      elsif string.index(/\^|\*|\//)
        @qty  = string
      else
        @qty  = string.index('.') ? string.to_f : string.to_i
      end
    elsif qty
      @qty  = qty.eval
    else
      @qty = 1
    end
    @unit = unit ? unit.to_s : nil
  end
  def eval
    self
  end
  def to_s
    return @unit unless @qty or @qty_range
    res = "#{@qty}#{@qty_range}"
    res = "#{res} #{@unit}" if @unit
    res
  end
end

class ParseSubstance
  attr_accessor  :name, :qty, :unit, :chemical_substance, :chemical_qty, :chemical_unit, :is_active_agent, :dose, :cdose, :is_excipiens
  attr_accessor  :description, :more_info, :salts
  def initialize(name, dose=nil)
    puts "ParseSubstance.new from #{name.inspect} #{dose.inspect}" if VERBOSE_MESSAGES
    @name = ParseUtil.capitalize(name.to_s)
    @name.sub!(/\baqua\b/i, 'aqua')
    @name.sub!(/\bDER\b/i, 'DER')
    @name.sub!(/\bad pulverem\b/i, 'ad pulverem')
    @name.sub!(/\bad iniectabilia\b/i, 'ad iniectabilia')
    @name.sub!(/\bad suspensionem\b/i, 'ad suspensionem')
    @name.sub!(/\bad solutionem\b/i, 'ad solutionem')
    @name.sub!(/\bpro compresso\b/i, 'pro compresso')
    @name.sub!(/\bpro\b/i, 'pro')
    @name.sub!(/ Q\.S\. /i, ' q.s. ')
    @name.sub!(/\s+\bpro$/i, '')
    @dose = dose if dose
    @salts = []
  end
  def qty
    return @dose.qty_range if @dose and @dose.qty_range
    @dose ? @dose.qty : @qty
  end
  def unit
    return @unit if @unit
    @dose ? @dose.unit : @unit
  end
  def to_string
    s = "#{@name}:"
    s = " #{@qty}" if @qty
    s = " #{@unit}" if @unit
    s += @chemical_substance.to_s if chemical_substance
    s
  end
end

class ParseComposition
  attr_accessor   :source, :label, :label_description, :substances, :galenic_form, :route_of_administration,
                  :corresp

  ErrorsToFix = { /(sulfuris D6\s[^\s]+\smg)\s([^,]+)/ => '\1, \2',
                  /(\d+)\s+\-\s*(\d+)/ => '\1-\2',
                  'o.1' => '0.1',
                  'g DER:' => 'g, DER:',
                  /(excipiens ad solutionem pro \d+ ml), corresp\./ => '\1 corresp.',
                  /^(pollinis allergeni extractum[^\:]+\:)/ => 'A): \1',
                  /^(acari allergeni extractum 5000 U\.\:)/ => 'A): \1',
                }
  @@errorHandler = ParseUtil::HandleSwissmedicErrors.new( ErrorsToFix )

  def initialize(source)
    @substances ||= []
    puts "ParseComposition.new from #{source.inspect} @substances #{@substances.inspect}" if VERBOSE_MESSAGES
    @source = source.to_s
  end
  def ParseComposition.reset
    @@errorHandler = ParseUtil::HandleSwissmedicErrors.new( ErrorsToFix )
  end
  def ParseComposition.report
    @@errorHandler.report
  end
  def ParseComposition.from_string(string)
    return nil if string == nil or  string.eql?('.') or string.eql?('')
    stripped = string.gsub(/^"|["\n]+$/, '')
    return nil unless stripped
    @@errorHandler.nrParsingErrors += 1
    if /(U\.I\.|U\.)$/.match(stripped)
      cleaned = stripped
    else
      cleaned = stripped.sub(/[\.]+$/, '')
    end
    value = nil
    puts "ParseComposition.from_string #{string}" if VERBOSE_MESSAGES # /ng-tr/.match(Socket.gethostbyname(Socket.gethostname).first)

    cleaned = @@errorHandler.apply_fixes(cleaned)
    puts "ParseComposition.new cleaned #{cleaned}" if VERBOSE_MESSAGES and not cleaned.eql?(stripped)

    CompositionTransformer.clear_substances
    result = ParseComposition.new(cleaned)
    parser3 = CompositionParser.new
    transf3 = CompositionTransformer.new
    begin
      if defined?(RSpec)
        ast = transf3.apply(parser3.parse_with_debug(cleaned))
        puts "#{File.basename(__FILE__)}:#{__LINE__}: ==>  #{ast}" if VERBOSE_MESSAGES
      else
        ast = transf3.apply(parser3.parse(cleaned))
      end
    rescue Parslet::ParseFailed => error
      puts "#{File.basename(__FILE__)}:#{__LINE__}: failed parsing ==>  #{cleaned}"
      return nil
    end
    result.source = string
    return result unless ast
    return result if ast.is_a?(Parslet::Slice)
    # pp ast; binding.pry

    result.substances = CompositionTransformer.substances
    excipiens = CompositionTransformer.excipiens
    result.corresp = CompositionTransformer.corresp if CompositionTransformer.corresp
    if excipiens and excipiens.unit
      pro_qty = "/#{excipiens.qty} #{excipiens.unit}".sub(/\/1\s+/, '/')
      result.substances.each {
        |substance|
          substance.chemical_substance.unit = "#{substance.chemical_substance.unit}#{pro_qty}"    if substance.chemical_substance
          substance.dose.unit               = "#{substance.dose.unit}#{pro_qty}"                  if substance.unit and not substance.unit.eql?(excipiens.unit)
      }
    end
    if ast.is_a?(Array) and  ast.first.is_a?(Hash)
      label = ast.first[:label].to_s if ast.first[:label]
      label_description = ast.first[:label_description].to_s if ast.first[:label_description]
    elsif ast and ast.is_a?(Hash)
      label = ast[:label].to_s if  ast[:label]
      label_description = ast[:label_description].to_s if ast[:label_description]
    end
    if label
      if label and not /((A|B|C|D|E|I|II|III|IV|\)+)\s+et\s+(A|B|C|D|E|I|II|III|IV|\))+)/.match(label)
        result.label  = label
      end
      result.label_description = label_description
    end
    @@errorHandler.nrParsingErrors -=1 if result.substances.size > 0 or result.corresp
    return result
  end
end
