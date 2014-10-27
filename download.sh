LOG_FILE=./download.log
TARGET_DIR=/mnt/storage/premiershiprugby/

touch $RTMP_LOG
./premiershiprugby.rb download --quality=high --formats=.flv --target=$TARGET_DIR --preview=false --skip=1 &>> $LOG_FILE
