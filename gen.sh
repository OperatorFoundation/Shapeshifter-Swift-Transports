swift package update
swift package generate-xcodeproj
rpl -R "10.10" "10.15" `basename $PWD`.xcodeproj/
open `basename $PWD`.xcodeproj
