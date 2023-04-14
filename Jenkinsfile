pipeline {
    agent { label 'arch' }
    stages {
        stage("Prepare system") {
            steps {
                sh 'pacman --noconfirm -Syu'
                sh 'pacman --noconfirm -S ruby base-devel clang llvm llvm-libs emscripten wget cmake'
            }
        }
        stage("Building") {
            steps {
                sh 'source /etc/profile.d/emscripten.sh && ruby ./build.rb --pack'
                archiveArtifacts artifacts: 'browser-llvm-*.tar.xz', followSymlinks: false
            }
        }
    }
}