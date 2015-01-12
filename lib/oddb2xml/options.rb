# encoding: utf-8
require 'optparse'

module Oddb2xml
  
  class Options
    attr_reader :parser, :opts
    def Options.default_opts
      {
        :fi           => false,
        :adr          => false,
        :address      => false,
        :nonpharma    => false,
        :extended     => false,
        :compress_ext => nil,
        :format       => :xml,
        :tag_suffix   => nil,
        :debug        => false,
        :ean14        => false,
        :skip_download=> false,
        :log          => false,
        :percent      => 0,
      }
    end
    def Options.help
  <<EOS
#$0 ver.#{Oddb2xml::VERSION}
Usage:
  oddb2xml [option]
    produced files are found under data
    -a T, --append=T     Additional target. T, only 'nonpharma' is available.
    -c F, --compress=F   Compress format F. {tar.gz|zip}
    -e    --extended     pharma, non-pharma plus prices and non-pharma from zurrose. Products without EAN-Code will also be listed.
    -f F, --format=F     File format F, default is xml. {xml|dat}
                         If F is given, -o option is ignored.
    -i I, --include=I    Include target option for 'dat' format. only 'ean14' is available.
                         'xml' format includes always ean14 records.
    -o O, --option=O     Optional output. O, only 'fi' is available.
    -p P, --price=P      Price source (transfer.dat). P, only 'zurrose' is available.
    -t S, --tag-suffix=S XML tag suffix S. Default is none. [A-z0-9]
                         If S is given, it is also used as prefix of filename.
    -x N, --context=N    context N {product|address}. product is default.

                         For debugging purposes
    --skip-download      skips downloading files it the file is already under downloads.
                         Downloaded files are saved under downloads
    --log                log important actions
    -h,   --help         Show this help message.
EOS
    end
    def initialize
      @parser = OptionParser.new
      @opts   = Options.default_opts
      @parser.on('-a v', '--append v',     /^nonpharma$/)  {|v| @opts[:nonpharma] = true }
      @parser.on('-c v', '--compress v',   /^tar\.gz|zip$/){|v| @opts[:compress_ext] = v }
      @parser.on('-e [x]', '--extended [x]')               {|v| @opts[:extended] = true
                                                          @opts[:nonpharma] = true
                                                          @opts[:price] = :zurrose
                                                          @opts[:percent] = v ? v.to_i : 0
                                                          }
      @parser.on('-f v', '--format v',     /^xml|dat$/)    {|v| @opts[:format] = v.intern }
      @parser.on('-o v', '--option v',     /^fi$/)         {|v| @opts[:fi] = true }
      @parser.on('-i v', '--include v',    /^ean14$/)      {|v| @opts[:ean14] = true }
      @parser.on('-t v', '--tag-suffix v', /^[A-z0-9]*$/i) {|v| @opts[:tag_suffix] = v.upcase }
      @parser.on('-x v', '--context v',    /^addr(ess)*$/i){|v| @opts[:address] = true }
      @parser.on('-p v', '--price v',      /^zurrose$/)    {|v| @opts[:price] = v.intern }
      @parser.on('--skip-download')                        {|v| @opts[:skip_download] = true }
      @parser.on('--log')                                  {|v| @opts[:log] = true }
      @parser.on_tail('-h', '--help') { puts Options.help; exit }
    end
  end
end
