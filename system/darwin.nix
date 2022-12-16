{ config, lib, pkgs, ... }:
{
  imports = [
    "${lib.expidus.channels.home-manager}/nix-darwin"
  ];

  system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;
  system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;

  system.defaults.dock.autohide = true;
  system.defaults.dock.mru-spaces = false;

  system.defaults.finder.ShowStatusBar = false;

  system.defaults.screencapture.disable-shadow = true;
  system.defaults.screencapture.location = "$HOME/Pictures";
  system.defaults.screencapture.type = "png";

  system.defaults.spaces.spans-displays = false;

  services.nix-daemon.enable = true;
  services.skhd.enable = true;

  services.yabai = {
    enable = true;
    package = pkgs.yabai;
    enableScriptingAddition = true;
    config = {
      external_bar = "main:32:0";

      mouse_modifier = "cmd";
      mouse_action1 = "move";
      mouse_action2 = "resize";
      mouse_drop_action = "sway";

      layout = "bsp";
      top_padding = 12;
      bottom_padding = 12;
      left_padding = 12;
      right_padding = 12;
      window_gap = 6;

      focus_follows_mouse = "autofocus";
      mouse_follows_focus = "on";

      window_topmost = "on";
      window_shadow = "float";
      window_placement = "second_child";
      window_border = "off";

      auto_balance = "on";
      split_ratio = 0.5;
    };
  };

  environment.loginShell = "${pkgs.zsh}/bin/zsh -l";
  environment.variables.SHELL = "${pkgs.zsh}/bin/zsh";
  environment.variables.LANG = "ja_JP.UTF-8";

  programs.bash.enableCompletion = true;

  environment.systemPackages = with pkgs; [
    coreutils
    git
    migu
    noto-fonts
    noto-fonts-emoji
    sketchybar
  ];

  launchd.user.agents.sketchybar = with lib;
    let
      plugins = builtins.mapAttrs
        (name: pkgs.writeShellScript "sketchybar-plugin-${name}.sh")
        {
          battery = ''
            PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
            CHARGING=$(pmset -g batt | grep 'AC Power')

            if [ $PERCENTAGE = "" ]; then
              exit 0
            fi

            sketchybar --set $NAME icon="🔋" label="''${PERCENTAGE}%"
          '';
          clock = ''
            sketchybar --set $NAME label="$(date '+%Y-%m-%d %H:%M')"
          '';
          display = ''
            set -e
            export PATH=${config.service.yabai.package}/bin:$PATH
            mon=$(yabai -m query --displays | jq ".[$1]")
            export NAME=display.$(($i + 1))

            function reset_color {
              sketchybar --set $NAME label.color=0xffa9b1d6
            }

            if ! [ "$mon" == "null" ]; then
              has_focus=$(echo $mon | jq ".spaces[]" | xargs -I % yabai -m query --windows --space % | jq ".[] | select(.\"has-focus\")")
              if ! [ -z "$has_focus" ]; then
                sketchybar --set $NAME label.color=0xff9ece6a
              else
                reset_color
              fi
            else
              reset_color
            fi
          '';
        };
    in {
      serviceConfig.ProgramArguments = [ "${pkgs.sketchybar}/bin/sketchybar" ];
      serviceConfig.KeepAlive = true;
      serviceConfig.RunAtLoad = true;
      serviceConfig.EnvironmentVariables = {
        PATH = "${pkgs.sketchybar}/bin:${config.environment.systemPath}";
      };
    };
}
