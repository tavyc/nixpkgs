/*

# Usage

`emacsWithPackages` takes a single argument: a function from a package
set to a list of packages (the packages that will be available in
Emacs). For example,
```
emacsWithPackages (epkgs: [ epkgs.evil epkgs.magit ])
```
All the packages in the list should come from the provided package
set. It is possible to add any package to the list, but the provided
set is guaranteed to have consistent dependencies and be built with
the correct version of Emacs.

# Overriding

`emacsWithPackages` inherits the package set which contains it, so the
correct way to override the provided package set is to override the
set which contains `emacsWithPackages`. For example, to override
`emacsPackagesNg.emacsWithPackages`,
```
let customEmacsPackages =
      emacsPackagesNg.override (super: self: {
        # use a custom version of emacs
        emacs = ...;
        # use the unstable MELPA version of magit
        magit = self.melpaPackages.magit;
      });
in customEmacsPackages.emacsWithPackages (epkgs: [ epkgs.evil epkgs.magit ])
```

*/

{ lib, makeWrapper, stdenv }: self:

with lib; let inherit (self) emacs; in

packagesFun: # packages explicitly requested by the user

let
  explicitRequires =
    if builtins.isFunction packagesFun
      then packagesFun self
    else packagesFun;
in

stdenv.mkDerivation {
  name = (appendToName "with-packages" emacs).name;
  nativeBuildInputs = [ emacs makeWrapper ];
  inherit emacs explicitRequires;
  phases = [ "installPhase" ];
  installPhase = ''
    local requires
    for pkg in $explicitRequires; do
      findInputs $pkg requires propagated-user-env-packages
    done
    # requires now holds all requested packages and their transitive dependencies

    siteStart="$out/share/emacs/site-lisp/site-start.el"

    addEmacsPath() {
      local list=$1
      local path=$2
      # Add the path to the search path list, but only if it exists
      if [[ -d "$path" ]]; then
        echo "(add-to-list '$list \"$path\")" >>"$siteStart"
      fi
    }

    # Add a dependency's paths to site-start.el
    addToEmacsPaths() {
      addEmacsPath "exec-path" "$1/bin"
      addEmacsPath "load-path" "$1/share/emacs/site-lisp"
      addEmacsPath "package-directory-list" "$1/share/emacs/site-lisp/elpa"
    }

    mkdir -p $out/share/emacs/site-lisp
    # Begin the new site-start.el by loading the original, which sets some
    # NixOS-specific paths. Paths are searched in the reverse of the order
    # they are specified in, so user and system profile paths are searched last.
    echo "(load-file \"$emacs/share/emacs/site-lisp/site-start.el\")" >"$siteStart"
    echo "(require 'package)" >>"$siteStart"

    # Set paths for the dependencies of the requested packages. These paths are
    # searched before the profile paths, but after the explicitly-required paths.
    for pkg in $requires; do
      # The explicitly-required packages are also in the list, but we will add
      # those paths last.
      if ! ( echo "$explicitRequires" | grep "$pkg" >/dev/null ) ; then
        addToEmacsPaths $pkg
      fi
    done

    # Finally, add paths for all the explicitly-required packages. These paths
    # will be searched first.
    for pkg in $explicitRequires; do
      addToEmacsPaths $pkg
    done

    # Byte-compiling improves start-up time only slightly, but costs nothing.
    emacs --batch -f batch-byte-compile "$siteStart"

    mkdir -p $out/bin
    # Wrap emacs and friends so they find our site-start.el before the original.
    for prog in $emacs/bin/*; do # */
      makeWrapper "$prog" $out/bin/$(basename "$prog") \
        --suffix EMACSLOADPATH ":" "$out/share/emacs/site-lisp:"
    done

    mkdir -p $out/share
    # Link icons and desktop files into place
    for dir in applications icons info man; do
      ln -s $emacs/share/$dir $out/share/$dir
    done
  '';
  inherit (emacs) meta;
}
