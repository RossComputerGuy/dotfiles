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
  services.skhd = {
    enable = true;
    # CMD is Super
    skhdConfig = ''
      cmd - s: screencapture -c
      cmd - return : /Applications/Alacritty.app/Contents/MacOS/alacritty --working-directory ~

      cmd - left : yabai -m window --focus west
      cmd - right : yabai -m window --focus east
      cmd - up : yabai -m window --focus north
      cmd - down : yabai -m window --focus south

      cmd + shift - left : yabai -m window --swap west
      cmd + shift - right : yabai -m window --swap east
      cmd + shift - up : yabai -m window --swap north
      cmd + shift - down : yabai -m window --swap south

      cmd - 1 : yabai -m display --focus 1
      cmd - 2 : yabai -m display --focus 2
      cmd - 3 : yabai -m display --focus 3
      cmd - 4 : yabai -m display --focus 4
      cmd - 5 : yabai -m display --focus 5
      cmd - 6 : yabai -m display --focus 6
      cmd - 7 : yabai -m display --focus 7
      cmd - 8 : yabai -m display --focus 8
      cmd - 9 : yabai -m display --focus 9
      cmd - 0 : yabai -m display --focus 10

      cmd + shift - 1 : yabai -m window --display 1; yabai -m display --focus 1
      cmd + shift - 2 : yabai -m window --display 2; yabai -m display --focus 2
      cmd + shift - 3 : yabai -m window --display 3; yabai -m display --focus 3
      cmd + shift - 4 : yabai -m window --display 4; yabai -m display --focus 4
      cmd + shift - 5 : yabai -m window --display 5; yabai -m display --focus 5
      cmd + shift - 6 : yabai -m window --display 6; yabai -m display --focus 6
      cmd + shift - 7 : yabai -m window --display 7; yabai -m display --focus 7
      cmd + shift - 8 : yabai -m window --display 8; yabai -m display --focus 8
      cmd + shift - 9 : yabai -m window --display 9; yabai -m display --focus 9
      cmd + shift - 0 : yabai -m window --display 10; yabai -m display --focus 10

      cmd + alt - 1: displayplacer "id:4FA81399-C168-BDED-6B38-53851AC566CD res:1920x1080 hz:60 color_depth:8 scaling:off origin:(0,0) degree:0" "id:E355FDB7-6122-50FF-7C47-22E7B65AC275 res:1920x1080 hz:60 color_depth:8 scaling:off origin:(0,-1080) degree:0" "id:FAC09570-592F-CA89-4057-4825CF51B3D1 res:1920x1080 hz:60 color_depth:8 scaling:off origin:(-1920,-1080) degree:0" "id:5ADCF2B5-AB50-2DB4-3A7D-14FE55D14FE8 res:1920x1080 hz:60 color_depth:8 scaling:off origin:(-1920,0) degree:0"
    '';
  };

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
