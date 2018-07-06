# download MongoSwift
if [ ! -d MongoSwift ]; then
  curl -# -L https://api.github.com/repos/mongodb/mongo-swift-driver/tarball/v0.0.2 > mongo-swift.tgz
  mkdir mongo-swift
  tar -xzf mongo-swift.tgz -C mongo-swift --strip-components 1

  cp -r mongo-swift/Sources/MongoSwift MongoSwift
  rm -rf mongo-swift mongo-swift.tgz
fi

if [ ! -d scripts/pbxproj ]; then
  git clone https://github.com/kronenthaler/mod-pbxproj.git --branch 2.5.1
  mv mod-pbxproj/pbxproj scripts
  rm -rf mod-pbxproj
fi

if [ ! -d Swifter ]; then
  curl -# -L https://api.github.com/repos/httpswift/swifter/tarball > swifter.tgz
  mkdir Swifter
  tar -xzf swifter.tgz -C Swifter --strip-components 1
  rm -rf swifter.tgz
fi

if [ ! -d JSONWebToken ]; then
  curl -# -L https://api.github.com/repos/kylef/JSONWebToken.swift/tarball > jsonwebtoken.tgz
  mkdir JSONWebToken

  tar -xzf jsonwebtoken.tgz -C JSONWebToken --strip-components 1
  rm -rf jsonwebtoken.tgz
fi

if [ ! -d CryptoSwift ]; then
  curl -# -L https://api.github.com/repos/krzyzanowskim/CryptoSwift/tarball > cryptoswift.tgz
  mkdir CryptoSwift
  tar -xzf cryptoswift.tgz -C CryptoSwift --strip-components 1
  rm -rf cryptoswift.tgz
fi
