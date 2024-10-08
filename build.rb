#!ruby
# This script builds llvm for usage inside the browser

require "fileutils"
require "etc"
require "optparse"

$llvm_version = "18.1.8"
$llvm_major = $llvm_version.split('.')[0]
$rel = "2"

if (ENV['GITHUB_OUTPUT'] != nil) then
    github_output = File.open(ENV["GITHUB_OUTPUT"], "at")
    github_output.write("version=#{$llvm_version}-#{$rel}\n")
    github_output.close()
end

$src_dir = File.absolute_path("llvm-#{$llvm_version}.src")
$lld_dir = File.absolute_path("lld-#{$llvm_version}.src")
$cmake_dir = File.absolute_path("cmake")
$ninja_jobs = ENV['NINJA_JOBS'] || (Etc.nprocessors / 2)

tblgen_exe = ENV['LLVMTBLGEN_EXE'] || '/usr/bin/llvm-tblgen'
puts "Using #{tblgen_exe} as llvm-tblgen"

$options = {
    :build_browser => true,
    :build_lld => true,
    :package => false,
}
OptionParser.new do |opts|
    opts.banner = "Usager: build.rb [options]"

    opts.on("--skip-browser", "Skips building of llvm via emscripten") do
        $options[:build_browser] = false
    end
    opts.on("--skip-lld", "Skips building of lld via emscripten") do
        $options[:build_lld] = false
    end
    opts.on("--package", "Build a package") do
        $options[:package] = true
    end
end.parse!

def download(url)
    ok = system("wget #{url}");
    exit 1 if !ok
end

def patch(file)
    Dir.chdir($src_dir) do
        puts ">>>> applying #{file}"
        $f = system("patch -N -p0 -i ../#{file}")
        if !$f then
            raise "Failed to apply patch #{file}"
        end
    end
end

def run(cmd)
    puts "$ #{cmd}"
    ok = system(cmd)
    exit 1 if !ok
end

# ----------------------------------------------------------------------------------

unless Dir.exist?($src_dir) then
    puts ">>>> downloading llvm #{$llvm_version}"
    download("https://github.com/llvm/llvm-project/releases/download/llvmorg-#{$llvm_version}/llvm-#{$llvm_version}.src.tar.xz")
    puts ">>>> extracting llvm #{$llvm_version}"
    system("tar -xf ./llvm-#{$llvm_version}.src.tar.xz -C .")
else
    puts ">>>> re-using existing llvm #{$llvm_version}"
end

unless Dir.exist?($lld_dir) then
    puts ">>>> downloading lld #{$llvm_version}"
    download("https://github.com/llvm/llvm-project/releases/download/llvmorg-#{$llvm_version}/lld-#{$llvm_version}.src.tar.xz")
    puts ">>>> extracting lld #{$llvm_version}"
    system("tar -xf ./lld-#{$llvm_version}.src.tar.xz -C .")
else
    puts ">>>> re-using existing lld #{$llvm_version}"
end

unless Dir.exist?($cmake_dir) then
    puts ">>>> downloading cmake for llvm #{$llvm_version}"
    download("https://github.com/llvm/llvm-project/releases/download/llvmorg-#{$llvm_version}/cmake-#{$llvm_version}.src.tar.xz")
    puts ">>>> extracting cmake for llvm #{$llvm_version}"
    run("tar -xf ./cmake-#{$llvm_version}.src.tar.xz -C .")
    run("mv cmake-#{$llvm_version}.src cmake")
else
    puts ">>>> re-using existing cmake for llvm #{$llvm_version}"
end

# patch llvm
patch("llvm-disable-default-includes.patch")
patch("llvm-add-wait4.patch")

# building llvm for the browser
puts ">>>> building llvm for the browser"

llvm_browser_builddir = File.absolute_path('./build/llvm-browser-Release')
llvm_browser_installdir = File.absolute_path('./install/llvm-browser-Release')
llvm_browser_targets = [
    'LLVMAggressiveInstCombine',
    'LLVMAnalysis',
    'LLVMAsmParser',
    'LLVMAsmPrinter',
    'LLVMBinaryFormat',
    'LLVMBitReader',
    'LLVMBitstreamReader',
    'LLVMBitWriter',
    'LLVMCFGuard',
    'LLVMCodeGen',
    'LLVMCodeGenTypes',
    'LLVMCore',
    'LLVMCoroutines',
    'LLVMCoverage',
    'LLVMDebugInfoCodeView',
    'LLVMDebugInfoDWARF',
    'LLVMDemangle',
    'LLVMFrontendOffloading',
    'LLVMFrontendOpenMP',
    'LLVMGlobalISel',
    'LLVMHipStdPar',
    'LLVMInstCombine',
    'LLVMInstrumentation',
    'LLVMipo',
    'LLVMIRReader',
    'LLVMLinker',
    'LLVMLTO',
    'LLVMMC',
    'LLVMMCDisassembler',
    'LLVMMCParser',
    'LLVMMIRParser',
    'LLVMObjCARCOpts',
    'LLVMObject',
    'LLVMOption',
    'LLVMPasses',
    'LLVMProfileData',
    'LLVMRemarks',
    'LLVMScalarOpts',
    'LLVMSelectionDAG',
    'LLVMSupport',
    'LLVMTarget',
    'LLVMTextAPI',
    'LLVMTransformUtils',
    'LLVMVectorize',
    'LLVMWebAssemblyAsmParser',
    'LLVMWebAssemblyCodeGen',
    'LLVMWebAssemblyDesc',
    'LLVMWebAssemblyInfo',
    'LLVMWebAssemblyUtils',
]

cmake_args = [
    '-G "Ninja"',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DLLVM_ENABLE_DUMP=OFF',
    '-DLLVM_ENABLE_ASSERTIONS=OFF',
    '-DLLVM_ENABLE_EXPENSIVE_CHECKS=OFF',
    '-DLLVM_ENABLE_BACKTRACES=OFF',
    "-DCMAKE_INSTALL_PREFIX='#{llvm_browser_installdir}'",
    '-DLLVM_TARGETS_TO_BUILD=WebAssembly',
    #'-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly',
    '-DLLVM_BUILD_TOOLS=OFF',
    '-DLLVM_ENABLE_THREADS=OFF',
    '-DLLVM_BUILD_LLVM_DYLIB=OFF',
    '-DLLVM_INCLUDE_TESTS=OFF', '-DLLVM_BUILD_TESTS=OFF',
    '-DLLVM_INCLUDE_EXAMPLES=OFF', '-DLLVM_BUILD_EXAMPLES=OFF',
    '-DLLVM_INCLUDE_BENCHMARKS=OFF',
    '-DBUILD_SHARED_LIBS=OFF',
    '-DLLVM_ENABLE_BINDINGS=OFF',
    "-DLLVM_TABLEGEN=#{tblgen_exe}",
]

if $options[:build_browser] then
    FileUtils.mkdir_p(llvm_browser_builddir)
    Dir.chdir(llvm_browser_builddir) do
        run("emcmake cmake #{cmake_args.join(' ')} #{$src_dir}")

        run("ninja -j#{$ninja_jobs} #{llvm_browser_targets.join(' ')}")
    end
end

# building lld for the browser
puts ">>>> building lld for the browser"

lld_browser_builddir = File.absolute_path('./build/lld-browser-Release')
lld_browser_installdir = File.absolute_path('./install/lld-browser-Release')
lld_browser_targets = [
    'lldCOFF',
    'lldCommon',
    'lldELF',
    'lldMachO',
    'lldMinGW',
    'lldWasm',
]
lld_cmake_args = [
    '-G "Ninja"',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DLLVM_INCLUDE_TESTS=OFF',
    '-DLLD_BUILD_TOOLS=OFF',
    "-DLLVM_DIR=#{llvm_browser_builddir}/lib/cmake/llvm",
    "-DLLVM_TABLEGEN_EXE=#{tblgen_exe}",
]

if $options[:build_lld] then
    FileUtils.mkdir_p(lld_browser_builddir)
    Dir.chdir(lld_browser_builddir) do
        run("emcmake cmake #{lld_cmake_args.join(' ')} #{$lld_dir}")
        run("ninja -j#{$ninja_jobs} #{lld_browser_targets.join(' ')}")
    end
end

def package(package_dir, builddir, src_dir)
    if Dir.exist?(package_dir) then
        FileUtils.rm_rf(package_dir)
    end

    FileUtils.mkdir_p(File.join(package_dir, "lib"))

    # copy builded headers
    for f in Dir.glob(File.join(builddir, "include", "**/*.{h,td,inc,def}"))
        next if (f.include?("CMakeFiles"))
        dir = File.dirname(f).gsub( builddir, package_dir )
        FileUtils.mkdir_p(dir)
        FileUtils.cp(f, "#{dir}/", :verbose => true)
    end

    # copy "normal" headers
    for f in Dir.glob(File.join(src_dir, "include", "**/*.{h,td,inc,def}"))
        next if (f.include?("CMakeFiles"))
        dir = File.dirname(f).gsub( src_dir, package_dir )
        FileUtils.mkdir_p(dir)
        FileUtils.cp(f, "#{dir}/", :verbose => true)
    end

    for f in Dir.glob(File.join(builddir, "lib", "*.a"))
        FileUtils.cp(f, "#{package_dir}/lib/", :verbose => true)
    end
end

def finish_shell_script(file)
    content = File.read(file)
    content.gsub!(/%LLVM_MAJOR%/, $llvm_major)
    content.gsub!(/%LLVM_VERSION%/, $llvm_version)
    File.write(file, content)
end

if $options[:package] then
    package_dir = "browser-llvm-#{$llvm_version}"
    package(package_dir, llvm_browser_builddir, $src_dir)
    FileUtils.mkdir_p(File.join(package_dir, "bin"))
    FileUtils.cp("./llvm-config-em", "#{package_dir}/bin/llvm-config-#{$llvm_major}-em", :verbose => true)
    finish_shell_script("#{package_dir}/bin/llvm-config-#{$llvm_major}-em")
    system("tar -cvJf browser-llvm-#{$llvm_version}-#{$rel}.tar.xz #{package_dir}")

    package_dir = "browser-lld-#{$llvm_version}"
    package(package_dir, lld_browser_builddir, $lld_dir)
    FileUtils.mkdir_p(File.join(package_dir, "bin"))
    FileUtils.cp("./lld-config-em", "#{package_dir}/bin/lld-config-#{$llvm_major}-em", :verbose => true)
    finish_shell_script("#{package_dir}/bin/lld-config-#{$llvm_major}-em")
    system("tar -cvJf browser-lld-#{$llvm_version}-#{$rel}.tar.xz #{package_dir}")
end
