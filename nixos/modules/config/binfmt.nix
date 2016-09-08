{ config, lib, pkgs, ... }:

with lib;

let

  binfmtOpts = { ... }:
    {
      options = {

        enable = mkEnableOption "this binfmt entry";

        offset = mkOption {
          default = 0;
          example = "0";
          type = types.int;
          description = ''
            The offset of the magic/mask in the file, counted in bytes.
          '';
        };

        magic = mkOption {
          default = "";
          example = literalExample ''
            "\\\\x7fELF"
          '';
          type = types.str;
          description = ''
            The byte sequence binfmt_misc is matching for. The magic string
            may contain hex-encoded characters like \\x0a or \\xA4.

            Note that you must escape any NUL bytes,
            and you must properly escape any \\ in Nix string expressions.
          '';
        };

        mask = mkOption {
          default = "";
          example = literalExample ''
            "\\\\xff\\\\xff"
          '';
          type = types.str;
          description = ''
            You can mask out some bits from matching by supplying a string like magic.
            The mask is anded with the byte sequence of the file.
          '';
        };

        extension = mkOption {
          default = null;
          example = ".exe";
          type = types.nullOr types.str;
          description = ''
            Filename extension to recognize instead of magic/mask.
          '';
        };

        interpreter = mkOption {
          example = literalExample ''
            "\${pkgs.qemu}/bin/qemu-arm\"
          '';
          type = types.path;
          description = ''
            The program that should be invoked with the binary as first argument.
          '';
        };

        flags = mkOption {
          default = "";
          example = "P";
          type = types.str;
          description = ''
            An optional string of capital letters that controls several aspects of the invocation of the interpreter.
            Refer to the binfmt_misc documentation for the meaning of the flags.
          '';
        };

      };
    };

in

{
  options = {

    boot.kernel.binfmt = {
      default = {};
      example = literalExample ''
        wine = {
          enable = true;
          magic = "MZ";
          interpreter = "\${pkgs.wine}/bin/wine";
        };
      '';
      type = types.attrsOf (types.submodule binfmtOpts);
      description = ''
        Additional binary formats.

        This Linux Kernel feature allows you to execute almost any program directly from your shell.

        Each element should be an attribute set specifying the magic bytes to match in the executable file
        and the path to the interpreter.

        See <link xlink:href="https://www.kernel.org/doc/Documentation/binfmt_misc.txt"/>
	for more details on this feature.
      '';
    };

  };

  config = {

    # Some useful entries, all disabled by default

    boot.kernel.binfmt = {

      wine = {
        enable = mkDefault false;
        magic = "MZ";
        interpreter = "${pkgs.wine}/bin/wine";
      };

      # qemu entries from qemu-2.6.1/scripts/qemu-binfmt-conf.sh

      qemu-arm = {
        enable = mkDefault false;
        magic = "\\x7fELF\\x01\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x28\\x00";
        mask = "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff";
        interpreter = "${pkgs.qemu}/bin/qemu-arm";
      };

      qemu-aarch64 = {
        enable = mkDefault false;
        magic = "\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xb7\\x00";
        mask = "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff";
        interpreter = "${pkgs.qemu}/bin/qemu-aarch64";
      };

    };

    environment.etc."binfmt.d/nixos.conf".text =
      let
        mkEntry = name: e:
          let
            type = if e.extension != null then "E" else "M";
            magic = if e.extension != null then e.extension else e.magic;
          in
            optionalString (e != null && e.enabled)
              ":${concatStringsSep ":" [ name type (toString e.offset) magic e.mask e.interpreter e.flags]}\n";
      in
        concatStrings (mapAttrsToList mkEntry config.boot.kernel.binfmt);

    systemd.services.systemd-binfmt.restartTriggers = [ config.environment.etc."binfmt.d/nixos.conf".source ];

  };

}
