# Create and cd into directory
def --env mkcd [dir: string] {
  mkdir $dir
  cd $dir
}

# Extract archives.
# The .rar branch intentionally degrades to an error when unrar is absent —
# same tradeoff as the fish feature (see its header note).
def ex [file: string] {
  match ($file | path extension) {
    "tar.bz2" => { ^tar xjf $file }
    "tar.gz" | "tgz" => { ^tar xzf $file }
    "bz2" => { ^bunzip2 $file }
    "rar" => { ^unrar x $file }
    "gz" => { ^gunzip $file }
    "tar" => { ^tar xf $file }
    "tbz2" => { ^tar xjf $file }
    "zip" => { ^unzip $file }
    "Z" => { ^uncompress $file }
    _ => { print $"($file) cannot be extracted" }
  }
}

# Search command history
def fh [] {
  history | get command | fzf --reverse --height 40%
}
