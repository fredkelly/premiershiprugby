LOG_FILE=./download.log
TARGET_DIR=/Users/freddy/Movies/Rugby

(bundle exec ./premiershiprugby.rb download --quality=high --formats=.flv --target=$TARGET_DIR --no-preview --skip=1 --limit=5 ) 2>> $LOG_FILE
