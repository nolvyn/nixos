{ den, ... }:
{
  den.aspects.rofi = {
    homeManager =
      { pkgs, ... }:
      {
        programs.rofi = {
          enable = true;
          package = pkgs.rofi;
          font = "Sans Serif 13";
          terminal = "${pkgs.kitty}/bin/kitty";
          theme = "moe";
        };

        xdg.dataFile."rofi/themes/moe.rasi".text = ''
          configuration {
            show-icons:   true;
            display-drun: "";
          }

          * {
            background-color: rgba(15, 21, 18, 0.95);
            border-color:     rgba(139, 214, 181, 0.5);
            text-color:       rgba(222, 228, 223, 1.0);
            spacing:          0;
            margin:           0;
            padding:          0;
          }

          window {
            width:         600px;
            border:        1px;
            border-radius: 12px;
            padding:       12px;
          }

          mainbox {
            padding: 8px;
          }

          inputbar {
            background-color: rgba(27, 33, 30, 1.0);
            border-radius:    8px;
            padding:          10px 12px;
            margin:           0px 0px 8px 0px;
            children:         [ prompt, entry ];
          }

          prompt {
            text-color: rgba(139, 214, 181, 1.0);
            padding:    0px 8px 0px 0px;
          }

          entry {
            text-color:        rgba(222, 228, 223, 1.0);
            placeholder-color: rgba(222, 228, 223, 0.4);
            placeholder:       "Search...";
          }

          listview {
            lines:     8;
            scrollbar: false;
            spacing:   2px;
          }

          element {
            padding:       8px 10px;
            border-radius: 6px;
          }

          element normal.normal {
            background-color: transparent;
            text-color:       rgba(222, 228, 223, 1.0);
          }

          element selected.normal {
            background-color: rgba(139, 214, 181, 0.15);
            text-color:       rgba(222, 228, 223, 1.0);
          }

          element-icon {
            size:    24px;
            padding: 0px 8px 0px 0px;
          }

          element-text {
            vertical-align: 0.5;
          }
        '';
      };
  };
}
