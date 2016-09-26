{ lib, stdenv, fetchFromGitHub, which, pkgconfig, kernel, iptables, net_snmp }:

stdenv.mkDerivation rec {
  name = "ipt-netflow-${version}-${kernel.version}";
  version = "2016-09-24";

  src = fetchFromGitHub {
    owner = "aabc";
    repo = "ipt-netflow";
    rev = "d4a6bb273721f70e74a3b9aec24c5150a58f9568";
    sha256 = "1jiki2vsa8kjsvjwlkvc0kr774kag1j4ydbx4bzz6nzska8z9q44";
  };

  nativeBuildInputs = [ which pkgconfig ];
  buildInputs = [ kernel iptables net_snmp ];

  hardeningDisable = [ "pic" ];

  postPatch = ''
    substituteInPlace configure --replace "/etc/snmp/snmpd.conf" "configure"
    substituteInPlace Makefile.in \
      --replace "/usr/" "/" \
      --replace "killall -0" "true"
  '';

  dontAddPrefix = true;
  KSRC = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/source";

  configureFlags = [
    "--kver=${kernel.modDirVersion}"
    "--kdir=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "--enable-natevents"
    "--enable-sampler"
    "--enable-snmp-rules"
    "--enable-macaddress"
    "--enable-vlan"
    "--enable-direction"
    "--enable-aggregation"
    "--enable-physdev"
    "--enable-promisc"
    "--disable-dkms"
  ];

  makeFlags = [
    "DESTDIR=$(out)"
    "IPTABLES_MODULES=/lib/xtables"
    "DEPMOD=true"
  ];

  meta = with lib; {
    inherit (src.meta) homepage;
    description = "High performance NetFlow v5, v9, IPFIX flow data export module for the Linux kernel";
    license = licenses.gpl2;
    platforms = platforms.linux;
    maintainers = with maintainers; [ tavyc ];
  };
}
