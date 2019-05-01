#!/bin/bash

pkg=$1
depot=/home/afrank/debcore-depot
failed_list=/home/afrank/src/debcore/repository/failed.txt

[[ "$pkg" ]] || exit 2

tmpdir=/tmp/${pkg}.${RANDOM}

echo "Chdir to $tmpdir"
mkdir -p $tmpdir
cd $tmpdir

export DEBIAN_FRONTEND=noninteractive

apt-get -y source $pkg
sudo apt-get update
sudo apt-get -y build-dep $pkg

dir=$(find . -mindepth 1 -maxdepth 1 -type d | head -1)
echo "Found dir: $dir"
if [[ "$dir" ]]; then
  cd $dir
  #DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -j10 -uc -us
  DEB_BUILD_OPTIONS=nocheck debuild -j10 -d -- build-arch binary-arch
  res=$?
  if [[ $res -ne 0 ]]; then
    echo $pkg >> $failed_list
  fi
  cd ..
fi

cp -v *.deb $depot/
#ls -la *.deb
