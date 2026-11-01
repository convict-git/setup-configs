id=yazi-previews
title="yazi · rich previews"
why="Previews of video, archives, JSON, PDFs, SVGs and images inside yazi."
requires=(yazi)
packages=(
  "brew ffmpeg"
  "brew sevenzip"
  "brew jq"
  "brew poppler"
  "brew resvg"
  "brew imagemagick"
  "brew chafa"
)

apply() { install_packages }
