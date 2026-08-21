# audio.nix

# For more information see https://wiki.nixos.org/wiki/Category:Audio
{ ... }:
{
  den.aspects.audio = {
    nixos = { host, ... }: {
      environment.persistence."/persistent".users.${host.userName}.directories = [
        ".local/state/wireplumber"
      ];

      services.pulseaudio.enable = false; # Use Pipewire, the modern sound subsystem
      security.rtkit.enable = true; # Enable RealtimeKit for audio purposes
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;

        # Fixes headophone audio change irregularities
        wireplumber = {
          extraScripts."bluetooth-volume-step.lua" = ''
            local cutils = require ("common-utils")

            local STEP = 0.05
            local TARGET_NODE_PATTERN = "bluez_output.40_72_18_BD_4B_07.*"

            local function get_volume (node)
              for param in node:iterate_params ("Props") do
                local props = cutils.parseParam (param, "Props")
                if props and props.channelVolumes and #props.channelVolumes > 0 then
                  -- Bluetooth stores the hardware volume as a cubic value;
                  -- convert it back to the percentage users see in wpctl.
                  return props.channelVolumes [1] ^ (1 / 3), props
                end
              end
              return nil, nil
            end

            local function set_volume (node, props, volume)
              local channel_volumes = { "Spa:Float" }
              local raw_volume = volume * volume * volume
              for _ in ipairs (props.channelVolumes) do
                table.insert (channel_volumes, raw_volume)
              end

              local param = Pod.Object {
                "Spa:Pod:Object:Param:Props", "Props",
                channelVolumes = Pod.Array (channel_volumes),
              }
              node:set_param ("Props", param)
            end

            local function normalize_volume (node)
              local volume, props = get_volume (node)
              if not volume then
                return
              end

              local target = math.min (1.0,
                  math.max (0.0, math.floor (volume / STEP + 0.5) * STEP))
              if math.abs (volume - target) > 0.001 then
                set_volume (node, props, target)
              end
            end

            SimpleEventHook {
              name = "bluetooth-volume-step/normalize",
              interests = {
                EventInterest {
                  Constraint { "event.type", "c", "node-added", "node-params-changed" },
                  Constraint { "node.name", "#", TARGET_NODE_PATTERN },
                  Constraint { "media.class", "=", "Audio/Sink" },
                },
              },
              execute = function (event)
                normalize_volume (event:get_subject ())
              end,
            }:register ()
          '';

          extraConfig."99-bluetooth-volume-step" = {
            "wireplumber.components" = [
              {
                name = "bluetooth-volume-step.lua";
                type = "script/lua";
                provides = "policy.bluetooth-volume-step";
                requires = [ "support.standard-event-source" ];
              }
            ];
            "wireplumber.profiles" = {
              main = {
                "policy.bluetooth-volume-step" = "required";
              };
            };
          };
        };
      };
    };

    homeManager = { pkgs, ... }: {
      home.packages = with pkgs; [ pwvucontrol ]; # Audio control GUI
    };
  };
}
