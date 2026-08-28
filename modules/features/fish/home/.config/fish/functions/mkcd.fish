function mkcd --description="Create and cd into directory"
    mkdir -p $argv[1] && cd $argv[1]
end