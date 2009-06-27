This.rubyforge_project = 'codeforpeople'
This.author = "Ara T. Howard"
This.email = "ara.t.howard@gmail.com"
This.homepage = "http://github.com/ahoward/#{ This.lib }/tree/master"


task :default do
  puts(Rake::Task.tasks.map{|task| task.name} - ['default'])
end

task :gemspec do
  ignore_extensions = 'git', 'svn', 'tmp', /sw./, 'bak', 'gem'
  ignore_directories = 'pkg'

  shiteless = 
    lambda do |list|
      list.delete_if do |entry|
        next unless test(?e, entry)
        extension = File.basename(entry).split(%r/[.]/).last
        ignore_extensions.any?{|ext| ext === extension}
      end
      list.delete_if do |entry|
        next unless test(?d, entry)
        dirname = File.expand_path(entry)
        ignore_directories.any?{|dir| File.expand_path(dir) == dirname}
      end
    end

  lib         = This.lib
  version     = This.version
  files       = shiteless[Dir::glob("**/**")]
  executables = shiteless[Dir::glob("bin/*")].map{|exe| File.basename(exe)}
  has_rdoc    = true #File.exist?('doc')
  test_files  = "test/#{ lib }.rb" if File.file?("test/#{ lib }.rb")

  extensions = This.extensions
  if extensions.nil?
    %w( Makefile configure extconf.rb ).each do |ext|
      extensions << ext if File.exists?(ext)
    end
  end
  extensions = [extensions].flatten.compact

  template = 
    if test(?e, 'gemspec.erb')
      Template{ IO.read('gemspec.erb') }
    else
      Template {
        <<-__
          ## #{ lib }.gemspec
          #

          Gem::Specification::new do |spec|
            spec.name = #{ lib.inspect }
            spec.version = #{ version.inspect }
            spec.platform = Gem::Platform::RUBY
            spec.summary = #{ lib.inspect }

            spec.files = #{ files.inspect }
            spec.executables = #{ executables.inspect }
            
            spec.require_path = "lib"

            spec.has_rdoc = #{ has_rdoc.inspect }
            spec.test_files = #{ test_files.inspect }
            #spec.add_dependency 'lib', '>= version'
            #spec.add_dependency 'fattr'

            spec.extensions.push(*#{ extensions.inspect })

            spec.rubyforge_project = #{ This.rubyforge_project.inspect }
            spec.author = #{ This.author.inspect }
            spec.email = #{ This.email.inspect }
            spec.homepage = #{ This.homepage.inspect }
          end
        __
      }
    end

  open("#{ lib }.gemspec", "w"){|fd| fd.puts template}
  This.gemspec = "#{ lib }.gemspec"
end

task :gem => [:clean, :gemspec] do
  Fu.mkdir_p This.pkgdir
  before = Dir['*.gem']
  cmd = "gem build #{ This.gemspec }"
  `#{ cmd }`
  after = Dir['*.gem']
  gem = ((after - before).first || after.first) or abort('no gem!')
  Fu.mv gem, This.pkgdir
  This.gem = File.basename(gem)
end

task :readme do
  samples = ''
  prompt = '~ > '
  lib = This.lib
  version = This.version

  Dir['sample*/*'].sort.each do |sample|
    samples << "\n" << "  <========< #{ sample } >========>" << "\n\n"

    cmd = "cat #{ sample }"
    samples << Util.indent(prompt + cmd, 2) << "\n\n"
    samples << Util.indent(`#{ cmd }`, 4) << "\n"

    cmd = "ruby #{ sample }"
    samples << Util.indent(prompt + cmd, 2) << "\n\n"

    cmd = "ruby -e'STDOUT.sync=true; exec %(ruby -Ilib #{ sample })'"
    samples << Util.indent(`#{ cmd } 2>&1`, 4) << "\n"
  end

  template = 
    if test(?e, 'readme.erb')
      Template{ IO.read('readme.erb') }
    else
      Template {
        <<-__
          NAME
            #{ lib }

          DESCRIPTION

          INSTALL
            gem install #{ lib }

          SAMPLES
            #{ samples }
        __
      }
    end

  open("README", "w"){|fd| fd.puts template}
end

task :clean do
  Dir[File.join(This.pkgdir, '**/**')].each{|entry| Fu.rm_rf(entry)}
end

task :release => [:clean, :gemspec, :gem] do
  gems = Dir[File.join(This.pkgdir, '*.gem')].flatten
  raise "which one? : #{ gems.inspect }" if gems.size > 1
  raise "no gems?" if gems.size < 1
  cmd = "rubyforge login && rubyforge add_release #{ This.rubyforge_project } #{ This.lib } #{ This.version } #{ This.pkgdir }/#{ This.gem }"
  puts cmd
  system cmd
end

namespace 'test' do
  def test_files(prefix=nil, &block)
    files = [ENV['FILES'], ENV['FILE']].flatten.compact
    if files.empty?
      files = Dir.glob("#{ prefix }/**/*.rb")
    else
      files.map!{|file| Dir.glob(file)}.flatten.compact
    end
    files = files.join(' ').strip.split(%r/\s+/)
    files.delete_if{|file| file =~ /(begin|ensure|setup|teardown).rb$/}
    files.delete_if{|file| !test(?s, file) or !test(?f, file)}
    files.delete_if{|file| !file[%r/#{ prefix }/]}
    block ? files.each{|file| block.call(file)} : files
  end

  desc 'run all tests'
  task 'all' => %w[ unit integration ] do
  end

  desc 'run unit tests'
  task 'unit' do
    test_files('test/unit/') do |file|
      test_loader file
    end
  end

  desc 'run integration tests'
  task 'integration' do
    test_files('test/integration/') do |file|
      test_loader file, :require_auth => true
    end
  end

  namespace 'integration' do
    task 'setup' do
      test_loader 'test/integration/setup.rb', :require_auth => true
    end
    task 'teardown' do
      test_loader 'test/integration/teardown.rb', :require_auth => true
    end
  end
end
task('test' => 'test:all'){}


BEGIN {
  $VERBOSE = nil

  require 'ostruct'
  require 'erb'
  require 'fileutils'

  Fu = FileUtils

  This = OpenStruct.new

  This.file = File.expand_path(__FILE__)
  This.dir = File.dirname(This.file)
  This.pkgdir = File.join(This.dir, 'pkg')

  lib = ENV['LIB']
  unless lib
    lib = File.basename(Dir.pwd)
  end
  This.lib = lib

  version = ENV['VERSION']
  unless version
    name = lib.capitalize
    require "./lib/#{ lib }"
    version = eval(name).send(:version)
  end
  This.version = version

  abort('no lib') unless This.lib
  abort('no version') unless This.version

  module Util
    def indent(s, n = 2)
      s = unindent(s)
      ws = ' ' * n
      s.gsub(%r/^/, ws)
    end

    def unindent(s)
      indent = nil
      s.each do |line|
      next if line =~ %r/^\s*$/
      indent = line[%r/^\s*/] and break
    end
    indent ? s.gsub(%r/^#{ indent }/, "") : s
  end
    extend self
  end

  class Template
    def initialize(&block)
      @block = block
      @template = block.call.to_s
    end
    def expand(b=nil)
      ERB.new(Util.unindent(@template)).result(b||@block)
    end
    alias_method 'to_s', 'expand'
  end
  def Template(*args, &block) Template.new(*args, &block) end

  Dir.chdir(This.dir)

  def test_loader basename, options = {}
    tests = ENV['TESTS']||ENV['TEST']
    tests = " -- -n #{ tests.inspect }" if tests
    auth = '-r test/auth.rb ' if options[:require_auth]
    command = "ruby -r test/loader.rb #{ auth }#{ basename }#{ tests }"
    STDERR.print "\n==== TEST ====\n  #{ command }\n\n==============\n"
    system command or abort("#{ command } # FAILED WITH #{ $?.inspect }")
  end
}
