#!/bin/bash

IMG_ROOT=/home/afrank/go/src/github.com/afrank/debcore/repository
#PKG_ROOT=/home/afrank/debcore
REPO_ROOT=$IMG_ROOT/debcore
PKG_INCOMING=$IMG_ROOT/incoming

# gpg-connect-agent reloadagent /bye

## rsync -av --remove-source-files -e "ssh -o StrictHostKeyChecking=no -i ~/.ssh/packager -p 22022" root@cloud-api.v2.stack.wit.com:/data/incoming/ $PKG_INCOMING/

mv $PKG_INCOMING/*.deb $PKG_INCOMING/main/ 2>/dev/null

for dir in $PKG_INCOMING/*; do
  component=$(basename $dir)
  reprepro -b $REPO_ROOT -C $component includedeb sid $dir/*.deb
done

reprepro -b $REPO_ROOT deleteunreferenced

#reprepro -b $REPO_ROOT export 
$IMG_ROOT/reprexpect.exp

#cp $IMG_ROOT/public.key $REPO_ROOT/

aws s3 sync debcore s3://mirrors.debcore.org/debian/
