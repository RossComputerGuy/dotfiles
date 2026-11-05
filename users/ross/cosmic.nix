{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.ross.cosmic;

  enum = variant: {
    __type = "enum";
    inherit variant;
  };
  optional = value: {
    __type = "optional";
    inherit value;
  };
  raw = value: {
    __type = "raw";
    inherit value;
  };
  applet = name: "com.system76.Cosmic${name}";

  # The frosted keys are the same for both builders. The laptop has them on in light mode too.
  frosted = {
    frosted_panel = true;
    frosted_applets = true;
    frosted_system_interface = true;
    frosted_windows = true;
  };

  # The panel and dock share these keys. cosmic-manager's panels option writes the old
  # autohide schema, which cannot hold Always, so both are written as raw config files.
  panel = entries: {
    version = 1;
    entries = {
      anchor_gap = false;
      autohide_behavior = raw "(wait_time: 1000, transition_time: 200, handle_size: 4, unhide_delay: 200)";
      autohover_delay_ms = optional 500;
      keep_style_on_maximize = false;
      keyboard_interactivity = enum "OnDemand";
      layer = enum "Top";
      margin = 0;
      opacity = 1.0;
      output = enum "All";
      padding_overlap = 0.5;
      size_center = optional null;
      size_wings = optional null;
      spacing = 0;
    } // entries;
  };
in
{
  imports = [ inputs.cosmic-manager.homeManagerModules.cosmic-manager ];

  options.ross.cosmic = {
    enable = lib.mkEnableOption "the shared COSMIC settings";

    panelExtraApplets = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "com.system76.CosmicAppletOsk" ];
      description = "Applets put first in the right side of the top panel.";
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.desktopManager.cosmic = {
      enable = true;

      configFile = {
        # Tokyo Night. The builder is the input, and build-theme makes the full theme from it.
        "com.system76.CosmicTheme.Dark.Builder" = {
          version = 2;
          entries = {
            accent = optional "#7AA2F7FF";
            bg_color = optional "#1A1B26FF";
            primary_container_bg = optional "#24283BFF";
            neutral_tint = optional "#414868FF";
            text_tint = optional "#CFC9C2FF";
            frosted = enum "Medium";
          } // frosted;
        };
        "com.system76.CosmicTheme.Light.Builder" = {
          version = 2;
          entries = frosted;
        };
        "com.system76.CosmicTheme.Mode" = {
          version = 1;
          entries.is_dark = true;
        };

        "com.system76.CosmicBackground" = {
          version = 1;
          entries = {
            same-on-all = true;
            all = raw ''(output: "all", source: Path("${config.home.homeDirectory}/Pictures/wallpaper.jpg"), filter_by_theme: true, rotation_frequency: 300, filter_method: Lanczos, scaling_mode: Zoom, sampling_method: Alphanumeric)'';
          };
        };

        "com.system76.CosmicComp" = {
          version = 1;
          entries = {
            autotile = true;
            autotile_behavior = enum "PerWorkspace";
            appearance_settings = {
              clip_floating_windows = true;
              clip_tiled_windows = true;
              shadow_tiled_windows = false;
            };
            xkb_config = raw ''(rules: "", model: "pc104", layout: "us", variant: "", options: Some("terminate:ctrl_alt_bksp"), repeat_delay: 600, repeat_rate: 25)'';
            # Natural scrolling is off. The whole struct is written, so it must keep tap to click.
            input_touchpad = raw "(state: Enabled, acceleration: Some((profile: Some(Adaptive), speed: 0.0)), click_method: Some(Clickfinger), disable_while_typing: Some(true), left_handed: Some(false), scroll_config: Some((method: Some(TwoFinger), natural_scroll: Some(false), scroll_button: None, scroll_factor: None)), tap_config: Some((enabled: true, button_map: Some(LeftRightMiddle), drag: true, drag_lock: false)))";
            input_default = raw "(state: Enabled, scroll_config: Some((method: None, natural_scroll: Some(false), scroll_button: None, scroll_factor: None)))";
          };
        };

        "com.system76.CosmicAppletTime" = {
          version = 1;
          entries = {
            military_time = true;
            first_day_of_week = 6;
          };
        };

        "com.system76.CosmicSettings.Shortcuts" = {
          version = 1;
          entries.system_actions = raw ''{ Terminal: "${lib.getExe pkgs.ghostty} --gtk-single-instance=true" }'';
        };

        "com.system76.CosmicPanel" = {
          version = 1;
          entries.entries = [
            "Panel"
            "Dock"
          ];
        };

        "com.system76.CosmicPanel.Panel" = panel {
          name = "Panel";
          anchor = enum "Top";
          autohide = enum "Never";
          background = enum "ThemeDefault";
          border_radius = 0;
          exclusive_zone = true;
          expand_to_edges = true;
          padding = 0;
          size = enum "XS";
          plugins_center = optional [ ];
          plugins_wings = optional {
            __type = "tuple";
            value = [
              (map applet [
                "PanelWorkspacesButton"
                "PanelAppButton"
              ])
              (
                cfg.panelExtraApplets
                ++ map applet [
                  "AppletInputSources"
                  "AppletA11y"
                  "AppletStatusArea"
                  "AppletTiling"
                  "AppletAudio"
                  "AppletBluetooth"
                  "AppletNetwork"
                  "AppletBattery"
                  "AppletNotifications"
                  "AppletTime"
                  "AppletPower"
                ]
              )
            ];
          };
        };

        "com.system76.CosmicPanel.Dock" = panel {
          name = "Dock";
          anchor = enum "Left";
          autohide = enum "Always";
          background = enum "ThemeDefault";
          border_radius = 12;
          exclusive_zone = false;
          expand_to_edges = false;
          padding = 4;
          size = enum "L";
          plugins_center = optional (
            map applet [
              "PanelLauncherButton"
              "PanelWorkspacesButton"
              "PanelAppButton"
              "AppList"
              "AppletMinimize"
            ]
          );
          plugins_wings = optional null;
        };
      };
    };

    # cosmic-manager only rebuilds the theme when its typed appearance options are set.
    home.activation.buildCosmicThemeRaw = lib.hm.dag.entryAfter [ "configureCosmic" ] ''
      run ${lib.getExe config.programs.cosmic-ext-ctl.package} build-theme
    '';
  };
}
