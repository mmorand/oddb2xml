#!/usr/bin/env ruby
# Helper script to test all common usageas of oddb2xml
# - runs rake install to install the gem
# - Creates an output directory ausgabe/time_stamp
# - runs all commands (and add ---skip-download)
# - saveds output and downloads to ausgabe/time_stamp


require 'fileutils'
require 'socket'

def test_one_call(cmd)
  dest = File.join(Ausgabe, cmd.gsub(/[ -]/, '_'))
  cmd.sub!('oddb2xml',  'oddb2xml --skip-download --log')
  files = (Dir.glob('%.xls*') + Dir.glob('*.dat*') + Dir.glob('*.xml'))
  FileUtils.rm(files, :verbose => true)
  puts "#{Time.now}: Running cmd #{cmd}"
  startTime = Time.now
  res = system(cmd)
  endTime = Time.now
  diffSeconds = (endTime - startTime).to_i
  duration = "#{Time.now}: Took #{sprintf('%3d', diffSeconds)} seconds for"
  puts "#{duration} success #{res} for #{cmd}"
  exit 2 unless res
  FileUtils.makedirs(dest)
  return unless File.directory?('downloads')
  FileUtils.cp_r('downloads', dest, :preserve => true, :verbose => true) if Dir.glob(Ausgabe).size > 0
  FileUtils.cp(Dir.glob('*.dat'), dest, :preserve => true, :verbose => true) if Dir.glob('*.dat').size > 0
  FileUtils.cp(Dir.glob('*.xml'), dest, :preserve => true, :verbose => true) if Dir.glob('*.xml').size > 0
  FileUtils.cp(Dir.glob('*.gz'),  dest, :preserve => true, :verbose => true) if Dir.glob('*.gz').size > 0
end

def prepare_for_gem_test
  [ "rake clean gem install"      , # build  and install our gem first
#    "gem uninstall --all --ignore-dependencies --executables",
    "gem install pkg/*.gem"
  ].each {
    |cmd|
      puts "Running #{cmd}"
      exit 1 unless system(cmd)
  }
end

Ausgabe = File.join(Dir.pwd, 'ausgabe', Time.now.strftime('%Y.%m.%d-%H:%M'))
puts "FQDN hostname #{Socket.gethostbyname(Socket.gethostname).first}"
FileUtils.makedirs(Ausgabe)
prepare_for_gem_test
# we will skip some long running tests as travis jobs must finish in less than 50 minutes
unless /travis/i.match(Socket.gethostbyname(Socket.gethostname).first)
  test_one_call('oddb2xml -e')
  test_one_call('oddb2xml -f dat -a nonpharma')
  test_one_call('oddb2xml -a nonpharma')
end
test_one_call('oddb2xml -t md -c tar.gz')
test_one_call('oddb2xml -f xml')
test_one_call('oddb2xml -x address')
test_one_call('oddb2xml -f dat')
test_one_call('oddb2xml -t md')