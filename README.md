# <img alt="logo" src="logo.png" height="50"> Premiership Rugby Downloader
Like rugby? Want to download your favourite games to watch at your leisure? Now you can...

## Usage

```bash
$ premiershiprugby help
Commands:
  premiershiprugby.rb download --target=TARGET  # lists all replay files
  premiershiprugby.rb help [COMMAND]            # Describe available commands or one specific comma
```

### Download Match/s

```bash
$ premiershiprugby.rb help download
Usage:
  premiershiprugby.rb download --target=TARGET

Options:
  [--preview], [--no-preview]  # preview without downloading
                               # Default: true
  --target=TARGET              # destination directory
  [--quality=QUALITY]          # file quality
                               # Possible values: high, low, iphone
  [--search=SEARCH]            # search query
  [--formats=one two three]    # file formats
                               # Possible values: .flv, .m4a
  [--limit=N]                  # number of results returned
  [--skip=N]                   # (rtmpdump) skip N keyframes when resuming
                               # Default: 0
$ premiershiprugby.rb download --quality=high --formats=.flv --target=./matches --no-preview --skip=1 --limit=5 2>> download.log
```

## Contributing

1. Fork it
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create new Pull Request and explain a little bit about your feature
