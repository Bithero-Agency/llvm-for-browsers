pipeline {
    agent { label 'arch' }
    stages {
        stage("Prepare system") {
            steps {
                sh 'echo "[bithero-pkgs]\nSigLevel = Optional TrustAll\nServer = http://archpkgs.ocb.red/bithero-pkgs" >> /etc/pacman.conf'
                sh 'pacman --noconfirm -Syu'
                sh 'pacman --noconfirm -S ruby base-devel clang llvm17 llvm17-libs llvm17-static emscripten wget cmake ninja'
            }
        }
        stage("Building") {
            steps {
                sh 'source /etc/profile.d/emscripten.sh && LLVMTBLGEN_EXE=/usr/lib/llvm17/bin/llvm-tblgen ruby ./build.rb --pack'
                archiveArtifacts artifacts: 'browser-*.tar.xz', followSymlinks: false
            }
        }
    }
}