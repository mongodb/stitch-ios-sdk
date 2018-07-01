mkdir -p Sources
# download MongoSwift
if [ ! -d MongoSwift ]; then
  curl -# -L https://api.github.com/repos/mongodb/mongo-swift-driver/tarball > mongo-swift.tgz
  mkdir mongo-swift
  # extract mongo-swift
  tar -xzf mongo-swift.tgz -C mongo-swift --strip-components 1

  # copy it to vendored Sources dir
  cp -r mongo-swift/Sources/MongoSwift MongoSwift
  # remove artifacts
  rm -rf mongo-swift mongo-swift.tgz
fi
