export JAVA_HOME="/usr/local/Cellar/openjdk@17/17.0.15/libexec/openjdk.jdk/Contents/Home"
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH=$JAVA_HOME/bin:$PATH
export PATH=~/.npm-global/bin:$PATH
export PATH="/usr/local/opt/postgresql/bin:$PATH"
export PATH="/usr/local/opt/postgresql@14/bin:$PATH"
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"
export ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/27.0.11394342
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH


# Load Angular CLI autocompletion.
source <(ng completion script)

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export JAVA_HOME=/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export JAVA_HOME="/usr/local/opt/openjdk@17"
