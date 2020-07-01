#!/bin/bash
#
# A bash script to run CircleCI node/test in parallel
#

NODE_INDEX=${CIRCLE_NODE_INDEX:-0}

set -e

function cleanup {
  # Show logs of 'petstore.swagger' container to troubleshoot Unit Test failures, if any.
  docker logs petstore.swagger # container name specified in circle.yml
}

trap cleanup EXIT

if [ "$NODE_INDEX" = "1" ]; then
  echo "Running node $NODE_INDEX to test 'samples.circleci' defined in pom.xml ..."
  java -version
  # Install golang version 1.14
  go version
  sudo mkdir /usr/local/go1.14
  wget -c https://dl.google.com/go/go1.14.linux-amd64.tar.gz -O - | sudo tar -xz -C /usr/local/go1.14
  export PATH="/usr/local/go1.14/go/bin:$PATH"
  go version

  mvn --no-snapshot-updates --quiet verify -Psamples.circleci -Dorg.slf4j.simpleLogger.defaultLogLevel=error
  mvn --no-snapshot-updates --quiet javadoc:javadoc -Psamples.circleci -Dorg.slf4j.simpleLogger.defaultLogLevel=error

elif [ "$NODE_INDEX" = "2" ]; then
  # run ensure-up-to-date sample script on SNAPSHOT version only
  project_version=`mvn org.apache.maven.plugins:maven-help-plugin:3.1.0:evaluate -Dexpression=project.version -q -DforceStdout`
  if [[ $project_version == *"-SNAPSHOT" ]]; then
    echo "Running node $NODE_INDEX to test ensure-up-to-date"
    java -version

    # clear any changes to the samples
    git checkout -- .

    # look for outdated samples
    ./bin/utils/ensure-up-to-date
  fi
#elif [ "$NODE_INDEX" = "3" ]; then
  echo "Running node $NODE_INDEX to test haskell"
  # install haskell
  curl -sSL https://get.haskellstack.org/ | sh
  stack upgrade
  stack --version
  # install r
  sudo sh -c 'echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list'
  gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
  gpg -a --export E084DAB9 | sudo apt-key add -
  sudo apt-get update
  sudo apt-get -y install r-base
  R --version
  # install curl
  sudo apt-get -y build-dep libcurl4-gnutls-dev
  sudo apt-get -y install libcurl4-gnutls-dev

  # run integration tests
  mvn --no-snapshot-updates --quiet verify -Psamples.misc -Dorg.slf4j.simpleLogger.defaultLogLevel=error
else
  echo "Running node $NODE_INDEX to test 'samples.circleci.jdk7' defined in pom.xml ..."
  # install dart2
  sudo apt-get update
  sudo apt-get install apt-transport-https
  sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
  sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
  sudo apt-get update
  sudo apt-get install dart
  export PATH="$PATH:/usr/lib/dart/bin"

  # install perl
  cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
  cpanm --quiet --no-interactive Test::Exception Test::More Log::Any LWP::UserAgent URI::Query Module::Runtime DateTime Module::Find Moose::Role JSON || echo "Igorned failure from cpanm"

  # install bats for bash
  sudo add-apt-repository ppa:duggan/bats --yes
  sudo apt-get update -qq
  sudo apt-get install -qq bats
  sudo apt-get install -qq curl

  # ruby
  ruby -v

  mvn --no-snapshot-updates --quiet verify -Psamples.circleci.jdk7 -Dorg.slf4j.simpleLogger.defaultLogLevel=error
fi


