# modules/desktop/apps/steam.nix

{ self, lib, config, options, pkgs, ... }:

with lib;
with self.lib;
let cfg = config.modules.desktop.apps.steam;
in {
  options.modules.desktop.apps.steam = with types; {
    enable = mkBoolOpt false;
    mangohud.enable = mkBoolOpt true;
    libraryDir = mkOpt str "";
  };

  config = mkIf cfg.enable {
    programs = {
      steam.enable = true;
      gamemode = {
        enable = true;
        settings = {
          general = {
            inhibit_screensaver = 0;
            renice = 10;
          };
          custom = {
            start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
            end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
          };
        };
      };
    };

    user.extraGroups = [ "gamemode" ];

    environment.systemPackages = with pkgs; [
      # Stop Steam from polluting $HOME
      (let pkg = config.programs.steam.package;
           # If the steam library lives on a shared NTFS drive, then we must
           # symlink steamapps/compatdata to a local directory, because Proton
           # will fail to produce certain paths that are illegal on an NTFS
           # filesystem (e.g. contains ":").
           libFix = writeShellScriptBin "libfix" ''
             if [[ "x${cfg.libraryDir}" != "x" ]]; then
               _libdir="${cfg.libraryDir}"
               if [[ -d "$_libdir" ]]; then
                 _steamdir="$_libdir/steamapps"
                 if [[ "$(stat -f -c %T "$_steamdir")" == "fuseblk" ]]; then
                   if [[ ! -L "$_steamdir/compatdata" ]]; then
                     rm -rf "$_steamdir/compatdata"
                   fi
                   if [[ ! -e "$_steamdir/compatdata" ]]; then
                     ln -s "$HOME/.steam/steam/steamapps/compatdata" "$_steamdir/compatdata"
                   fi
                 fi
               fi
             fi
           '';
       in mkWrapper [
         pkg
         pkg.run   # for GOG and humble bundle games
       ] ''
         wrapProgram "$out/bin/steam" \
           --run 'export HOME="$XDG_FAKE_HOME"' \
           --run '${libFix}/bin/libfix'
         wrapProgram "$out/bin/steam-run" --run 'export HOME="$XDG_FAKE_HOME"'
       '')
    ] ++ (if cfg.mangohud.enable then [ pkgs.mangohud ] else []);

    # Better for steam proton games
    systemd.extraConfig = "DefaultLimitNOFILE=1048576";
  };
}
