#!ruby
# This ruby script builds the llvm-config-em script required for the llvm release

require "fileutils"
require "optparse"
require "json"

$options = {
    :build_dir => nil,
    :output => nil,
}
OptionParser.new do |opts|
    opts.banner = "Usager: build_llvm_config_script.rb [options]"

    opts.on("--build-dir DIR", "Specified the build directory") do |dir|
        $options[:build_dir] = dir
    end
    opts.on("--output OUT", "Specifies the output file") do |out|
        $options[:output] = out
    end
end.parse!

if $options[:build_dir].nil? || $options[:output].nil? then
    puts "Required flags not provided: --build-dir and/or --output"
    exit(1)
end

class AvailableComponent
    attr_accessor :name, :libname, :is_installed, :required_libs
    def initialize(comp)
        @name = comp[0];
        @libname = comp[1];
        @is_installed = comp[2];
        @required_libs = comp[3];
    end
end

def read_comp_info(path)
    deps = File.read(path);
    deps.gsub!(/^.*\}\s*AvailableComponents\[\d+\]\s*=\s*\{/m, '');
    deps.gsub!(/}\s*;$/, '');
    deps.strip!;
    comps=[]
    deps.lines do |comp|
        comp.gsub!('{', '[');
        comp.gsub!('}', ']');
        comp.strip!;
        comp.gsub!(/,$/, '');
        comp.gsub!('nullptr', 'null');
        comp = JSON.parse(comp);
        comps.push AvailableComponent.new(comp)
    end
    return comps
end

comps = read_comp_info(File.join(
    $options[:build_dir],
    'tools',
    'llvm-config',
    'LibraryDependencies.inc'
))
puts "Loaded #{comps.size} component infos..."

script = File.read("./llvm-config-em")

libnames = comps.map {|comp|
    next "libs[#{comp.name}]=\"#{comp.libname}\""
}.join("\n")
script.gsub!('##__LIB_NAMES__', libnames)

deps = comps.map {|comp|
    next "comp_deps[#{comp.name}]=\"#{comp.required_libs.join(' ')}\""
}.join("\n")
script.gsub!('##__COMP_DEPS__', deps)

names = comps.map {|comp| comp.name}.join(' ')
script.gsub!('__COMPONENTS__', names)

File.write($options[:output], script)
puts "Written #{$options[:output]}..."
