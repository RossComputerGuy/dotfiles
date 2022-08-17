#!/bin/sh

brew install koekeishiya/formulae/yabai
brew install koekeishiya/formulae/skhd
brew install FelixKratz/formulae/sketchybar

brew services start sketchybar
brew services start skhd
brew services start yabai

defaults write com.apple.spaces spans-displays -bool false
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock "mru-spaces" -bool "false"
defaults write com.apple.screencapture location -string "$HOME/Desktop"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture type -string "png"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain _HIHideMenuBar -bool true
defaults write NSGlobalDomain AppleHighlightColor -string "0.615686 0.823529 0.454902"
defaults write NSGlobalDomain AppleAccentColor -int 1
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
defaults write com.apple.finder ShowStatusBar -bool false
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
