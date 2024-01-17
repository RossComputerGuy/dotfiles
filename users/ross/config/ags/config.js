import Battery from 'resource:///com/github/Aylur/ags/service/battery.js';
import Hyprland from 'resource:///com/github/Aylur/ags/service/hyprland.js';
import Mpris from 'resource:///com/github/Aylur/ags/service/mpris.js';
import Network from 'resource:///com/github/Aylur/ags/service/network.js';
import SystemTray from 'resource:///com/github/Aylur/ags/service/systemtray.js';
import App from 'resource:///com/github/Aylur/ags/app.js';
import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import { USER, exec, execAsync, lookUpIcon } from 'resource:///com/github/Aylur/ags/utils.js';
import Gdk from 'gi://Gdk';

const range = (length, start = 1) => Array.from({ length }, (_, i) => i + start);

function forMonitors(widget) {
  const n = Gdk.Display.get_default()?.get_n_monitors() || 1;
  return range(n, 0).map(widget).flat(1);
}

const Workspaces = () => Widget.Box({
  class_name: 'workspaces',
  spacing: 2,
  children: Hyprland.bind('workspaces').transform(ws => {
    ws.sort((a, b) => a.id - b.id);
    return ws.map(({ id }) => Widget.Button({
      on_clicked: () => Hyprland.sendMessage(`dispatch workspace ${id}`),
      child: Widget.Label(`${id}`),
      class_name: Hyprland.active.workspace.bind('id')
        .transform(i => i === id ? 'focused' : ''),
    }))
  }),
});

const ClockButton = ({ children = [], on_clicked = () => {} }) => {
  const dateReveal = Widget.Revealer({
    transition: 'slide_right',
    transition_duration: 300,
    child: Widget.Label({
      class_name: 'clock-date',
      setup: self => self
        .poll(1000, self => self.label = exec('date "+%Y-%m-%d"')),
    }),
  });


  return Widget.Button({
    on_hover: () => {
      dateReveal.reveal_child = true;
    },
    on_hover_lost: () => {
      dateReveal.reveal_child = false;
    },
    on_clicked: on_clicked,
    child: Widget.Box({
      spacing: 2,
      children: [
        ...children,
        Widget.Label({
          class_name: 'clock-time',
          setup: self => self
            .poll(1000, self => self.label = exec('date "+%H:%M"')),
        }),
        dateReveal,
      ],
    }),
  });
};

const Panel = (monitor = 0) => Widget.Window({
  name: `panel-${monitor}`,
  class_name: 'panel',
  monitor,
  anchor: ['top', 'left', 'right'],
  exclusivity: 'exclusive',
  margins: [4, 4, 4],
  child: Widget.CenterBox({
    start_widget: Widget.Box({
      spacing: 2,
      children: [
        Workspaces(),
      ],
    }),
    center_widget: Widget.Button({
      class_name: 'music',
      on_clicked: () => {
        App.toggleWindow(`mediainfo-${monitor}`);
      },
      visible: Mpris.bind('players').transform(p => p.length > 0),
      child: Widget.Box({
        spacing: 2,
        children: Mpris.bind('players').transform(players => {
          if (players.length == 0) return [];

          if (players.length == 1) {
            const player = players[0];

            return [
              Widget.Icon({
                icon: player.bind('entry').transform(entry => {
                  const name = `${entry}-symbolic`;
                  return lookUpIcon(name) ? name : 'audio-x-generic-symbolic';
                }),
              }),
              Widget.Label({
                label: player.bind('track-title'),
              }),
            ];
          }

          return [
            Widget.Icon('audio-speakers'),
            ...players.filter((item, i) => {
              const x = players.findIndex(item2 => item2.entry == item.entry);
              return x == i;
            }).map(player => Widget.Box({
              spacing: 2,
              children: [
                Widget.Icon({
                  icon: player.bind('entry').transform(entry => {
                    const name = `${entry}-symbolic`;
                    return lookUpIcon(name) ? name : 'audio-x-generic-symbolic';
                  }),
                }),
                Widget.Label({
                  label: player.bind('identity'),
                }),
              ],
            })),
          ];
        }),
      }),
    }),
    end_widget: Widget.Box({
      spacing: 2,
      hpack: 'end',
      children: [
        Widget.Box()
          .bind('children', SystemTray, 'items', i => i.map(item =>
            Widget.Button({
              child: Widget.Icon().bind('icon', item, 'icon'),
              tooltipMarkup: item.bind('tooltip-markup'),
              onPrimaryClick: (_, ev) => item.activate(ev),
              onSecondaryClick: (_, ev) => item.openMenu(ev),
            })
          )),
        ClockButton({
          on_clicked: () => {
            App.toggleWindow(`quicksettings-${monitor}`);
          },
          children: [
            Widget.Box({
              spacing: 2,
              visible: Battery.bind('available'),
              children: [
                Widget.Icon({ icon: Battery.bind('icon_name') }),
                Widget.Label({ label: Battery.bind('percent').transform(p => p + '%') }),
              ],
            }),
          ],
        }),
      ],
    }),
  }),
});

const Brightness = (device = null, icon = 'display') => Widget.Box({
  children: [
    Widget.Icon(`${icon}-brightness-symbolic`),
    Widget.Slider({
      hexpand: true,
      draw_value: false,
      on_change: ({ value, max }) =>
        execAsync(`brightnessctl ${device !== null ? '-d ' + device : ''} s ${(value / max) * 100}% -q`),
      setup: self => {
        execAsync(`brightnessctl ${device !== null ? '-d ' + device : ''} m`)
          .then((value) => {
            self.max = value;
          })

        execAsync(`brightnessctl ${device !== null ? '-d ' + device : ''} g`)
          .then((value) => {
            self.value = value;
          })
      },
    }),
  ],
});


const QuickSettings = (monitor = 0) => Widget.Window({
  name: `quicksettings-${monitor}`,
  class_name: 'quicksettings',
  popup: true,
  focusable: true,
  anchor: ['top', 'right'],
  margins: [4, 4],
  setup: self => {
    self.toggleClassName('window-content');
    self.show_all();
    self.visible = false;
  },
  child: Widget.Box({
    css: 'padding: 1px',
    child: Widget.Revealer({
      transition: 'slide_down',
      transition_duration: 300,
      setup: self => self.hook(App, (_, wname, visible) => {
        if (wname === `quicksettings-${monitor}`) self.reveal_child = visible;
      }),
      child: Widget.Box({
        vertical: true,
        children: [
          Widget.Box({
            children: [
              Widget.Box({
                class_name: 'avatar',
                setup: self => {
                  self.setCss(`
                  background-image: url('/home/${USER}/.face');
                  background-size: cover;
                  `);

                  self.on('size-allocate', box => {
                    const h = box.get_allocated_height();
                    box.set_size_request(Math.ceil(h * 1.1), -1);
                  });
                },
              }),
              Widget.Box({
                hpack: 'end',
                vpack: 'center',
                hexpand: true,
                spacing: 8,
                children: [
                  Widget.Label({
                    class_name: 'uptime',
                    setup: self => self
                      .poll(1000, self => {
                        const uptime = Number.parseInt(exec('cat /proc/uptime').split('.')[0]) / 60;
                        const h = Math.floor(uptime / 60);
                        const s = Math.floor(uptime % 50);
                        self.label = `Uptime: ${h}:${s < 10 ? '0' + s : s}`;
                      }),
                  }),
                  Widget.Box({
                    vertical: true,
                    spacing: 4,
                    children: [
                      Widget.Box({
                        spacing: 4,
                        children: [
                          Widget.Button({
                            child: Widget.Icon('system-shutdown'),
                            on_clicked: () => exec('systemctl poweroff'),
                          }),
                          Widget.Button({
                            child: Widget.Icon('system-reboot'),
                            on_clicked: () => exec('systemctl reboot'),
                          }),
                        ],
                      }),
                      Widget.Box({
                        spacing: 4,
                        children: [
                          Widget.Button({
                            child: Widget.Icon('weather-clear-night'),
                            on_clicked: () => exec('systemctl suspend'),
                          }),
                          Widget.Button({
                            child: Widget.Icon('system-log-out'),
                            on_clicked: () => Hyprland.sendMessage('dispatch exit'),
                          }),
                        ],
                      }),
                    ],
                  }),
                ],
              }),
            ],
          }),
          Brightness(),
          Brightness('kbd_backlight', 'keyboard'),
          Widget.Box({
            class_name: 'network',
            children: [
              Widget.Button({
                child: Widget.Box({
                  hexpand: true,
                  class_name: 'label-box horizontal',
                  spacing: 4,
                  children: [
                    Widget.Icon({ icon: Network.wifi.bind('icon_name') }),
                    Widget.Label({
                      hexpand: true,
                      justification: 'left',
                      truncate: 'end',
                      label: Network.wifi.bind('ssid').transform(ssid => ssid || 'Not Connected'),
                    }),
                  ],
                }),
                on_primary_click: (_, ev) => Widget.Menu({
                  children: Network.wifi?.access_points.map(ap =>
                    Widget.MenuItem({
                      child: Widget.Box({
                        children: [
                          Widget.Icon(ap.iconName),
                          Widget.Label(ap.ssid || 'Unknown Network'),
                        ],
                      }),
                      on_activate: () => execAsync(`nmcli device wifi connect ${ap.bssid}`),
                    })
                  ),
                }).popup_at_pointer(ev),
              }),
              Widget.Switch({
                hpack: 'end',
                active: Network.wifi.bind('enabled'),
                setup: self => self.connect('notify::active', () => {
                  Network.wifi.enabled = self.active;
                  if (self.active) Network.wifi.scan();
                }),
              }),
            ],
          }),
        ],
      }),
    }),
  }),
});

const MediaInfo = (monitor = 0) => {
  const geom = Gdk.Display.get_default()?.get_monitor(monitor).geometry;

  const lengthStr = (length) => {
    const min = Math.floor(length / 60);
    const sec = Math.floor(length % 60);
    const sec0 = sec < 10 ? '0' : '';
    return `${min}:${sec0}${sec}`;
  };

  return Widget.Window({
    name: `mediainfo-${monitor}`,
    class_name: 'mediainfo',
    popup: true,
    focusable: true,
    anchor: ['top', 'left', 'right'],
    margins: [4, 4 + (geom.width / 2.7), 4 + (geom.width / 2.7)],
    setup: self => {
      self.toggleClassName('window-content');
      self.show_all();
      self.visible = false;
    },
    child: Widget.Box({
      css: 'padding: 1px',
      child: Widget.Revealer({
        transition: 'slide_down',
        transition_duration: 300,
        setup: self => self.hook(App, (_, wname, visible) => {
          if (wname === `mediainfo-${monitor}`) self.reveal_child = visible;
        }),
        child: Widget.Box({
          spacing: 3,
          vertical: true,
          children: Mpris.bind('players').transform(players => players.map(player =>
            Widget.Box({
              class_name: 'player',
              children: [
                Widget.Box({
                  class_name: 'img',
                  vpack: 'start',
                  css: player.bind('cover_path').transform(p => `
                    background-image: url('${p}');
                  `),
                }),
                Widget.Box({
                  vertical: true,
                  hexpand: true,
                  children: [
                    Widget.Box({
                      children: [
                        Widget.Label({
                          class_name: 'title',
                          wrap: true,
                          hpack: 'start',
                          label: player.bind('track_title'),
                        }),
                        Widget.Icon({
                          class_name: 'icon',
                          hexpand: true,
                          hpack: 'end',
                          vpack: 'start',
                          tooltip_text: player.identity || '',
                          icon: player.bind('entry').transform(entry => {
                            const name = `${entry}-symbolic`;
                            return lookUpIcon(name) ? name : 'audio-x-generic-symbolic';
                          }),
                        }),
                      ],
                    }),
                    Widget.Label({
                      class_name: 'artist',
                      wrap: true,
                      hpack: 'start',
                      label: player.bind('track_artists').transform(a => a.join(', ')),
                    }),
                    Widget.Box({ vexpand: true }),
                    Widget.Slider({
                      class_name: 'position',
                      draw_value: false,
                      on_change: ({ value }) => player.position = value * player.length,
                      setup: self => {
                        const update = () => {
                          self.visible = player.length > 0;
                          self.value = player.position / player.length;
                        };

                        self.hook(player, update);
                        self.hook(player, update, 'position');
                        self.poll(1000, update);
                      },
                    }),
                    Widget.CenterBox({
                      start_widget: Widget.Label({
                        class_name: 'position',
                        hpack: 'start',
                        setup: self => {
                          const update = (_, time) => {
                            self.label = lengthStr(time || player.position)
                            self.visible = player.length > 0;
                          };

                          self.hook(player, update, 'position');
                          self.poll(1000, update);
                        },
                      }),
                      center_widget: Widget.Box({
                        children: [
                          Widget.Button({
                            on_clicked: () => player.previous(),
                            visible: player.bind('can_go_prev'),
                            child: Widget.Icon('media-skip-backward-symbolic'),
                          }),
                          Widget.Button({
                            class_name: 'play-pause',
                            on_clicked: () => player.playPause(),
                            visible: player.bind('can_play'),
                            child: Widget.Icon({
                              icon: player.bind('play_back_status').transform(s => {
                                switch (s) {
                                  case 'Playing': return 'media-playback-pause-symbolic';
                                  case 'Paused':
                                  case 'Stopped': return 'media-playback-start-symbolic';
                                }
                              }),
                            }),
                          }),
                          Widget.Button({
                            on_clicked: () => player.next(),
                            visible: player.bind('can_go_next'),
                            child: Widget.Icon('media-skip-forward-symbolic'),
                          }),
                        ],
                      }),
                      end_widget: Widget.Label({
                        class_name: 'length',
                        hpack: 'end',
                        visible: player.bind('length').transform(l => l > 0),
                        label: player.bind('length').transform(lengthStr),
                      }),
                    }),
                  ],
                }),
              ],
            })
          )),
        }),
      }),
    }),
  });
};

export default {
  style: App.configDir + '/style.css',
  windows: [
    forMonitors(Panel),
    forMonitors(QuickSettings),
    forMonitors(MediaInfo),
  ].flat(1),
};
