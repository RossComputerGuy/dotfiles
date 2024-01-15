import Battery from 'resource:///com/github/Aylur/ags/service/battery.js';
import Hyprland from 'resource:///com/github/Aylur/ags/service/hyprland.js';
import Network from 'resource:///com/github/Aylur/ags/service/network.js';
import SystemTray from 'resource:///com/github/Aylur/ags/service/systemtray.js';
import App from 'resource:///com/github/Aylur/ags/app.js';
import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import { USER, exec, execAsync } from 'resource:///com/github/Aylur/ags/utils.js';

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

export default {
  style: App.configDir + '/style.css',
  windows: [
    Panel(),
    QuickSettings(),
  ],
};
