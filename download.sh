LOG_FILE=./download.log
TARGET_DIR=/mnt/storage/premiershiprugby/

( ./premiershiprugby.rb download --quality=high --formats=.flv --target=$TARGET_DIR --no-preview --skip=1 --limit=1 ) 2>> $LOG_FILE
