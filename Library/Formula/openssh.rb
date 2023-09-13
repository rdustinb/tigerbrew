class Openssh < Formula
  desc "OpenBSD freely-licensed SSH connectivity tools"
  homepage "https://www.openssh.com/"
  url "https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.4p1.tar.gz"
  mirror "https://cloudflare.cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.4p1.tar.gz"
  version "9.4p1"
  sha256 "3608fd9088db2163ceb3e600c85ab79d0de3d221e59192ea1923e23263866a85"
  license "SSH-OpenSSH"

  bottle do
    sha256 "ad3accf8ec0c1325f9fbcee0e11c99e7e7b7556931a80d6d4c2cefe49902d76f" => :tiger_altivec
  end

  # Please don't resubmit the keychain patch option. It will never be accepted.
  # https://archive.is/hSB6d#10%25

  depends_on "pkg-config" => :build
  depends_on "ldns"
  depends_on "openssl"
  depends_on "zlib"

    # Both these patches are applied by Apple.
    # https://github.com/apple-oss-distributions/OpenSSH/blob/main/openssh/sandbox-darwin.c#L66
    patch do
      url "https://raw.githubusercontent.com/Homebrew/patches/1860b0a745f1fe726900974845d1b0dd3c3398d6/openssh/patch-sandbox-darwin.c-apple-sandbox-named-external.diff"
      sha256 "d886b98f99fd27e3157b02b5b57f3fb49f43fd33806195970d4567f12be66e71"
    end

    # https://github.com/apple-oss-distributions/OpenSSH/blob/main/openssh/sshd.c#L532
    patch do
      url "https://raw.githubusercontent.com/Homebrew/patches/d8b2d8c2612fd251ac6de17bf0cc5174c3aab94c/openssh/patch-sshd.c-apple-sandbox-named-external.diff"
      sha256 "3505c58bf1e584c8af92d916fe5f3f1899a6b15cc64a00ddece1dc0874b2f78f"
    end

  resource "com.openssh.sshd.sb" do
    url "https://raw.githubusercontent.com/apple-oss-distributions/OpenSSH/OpenSSH-268.100.4/com.openssh.sshd.sb"
    sha256 "a273f86360ea5da3910cfa4c118be931d10904267605cdd4b2055ced3a829774"
  end

  # Fix zlib version check for 1.3 and future version.
  # This can be removed in next version
  patch do
    url "https://github.com/openssh/openssh-portable/commit/cb4ed12ffc332d1f72d054ed92655b5f1c38f621.diff"
    sha256 "60d057bc1752ac6802f9e9cd160c9838678b9e2e615b441ef6cc8ac8cb28f47f"
  end
  # Patch configure to avoid autoreconf
  # This can be removed in next version
  patch :p0, :DATA

  def install
    args = %W[
      --prefix=#{prefix}
      --sysconfdir=#{etc}/ssh
      --with-ldns
      --with-libedit
      --with-kerberos5
      --with-pam
      --with-ssl-dir=#{Formula["openssl"].opt_prefix}
      --with-zlib=#{Formula["zlib"].opt_prefix}
    ]

    if OS.mac?
      ENV.append "CPPFLAGS", "-D__APPLE_SANDBOX_NAMED_EXTERNAL__"

      # Ensure sandbox profile prefix is correct.
      # We introduce this issue with patching, it's not an upstream bug.
      inreplace "sandbox-darwin.c", "@PREFIX@/share/openssh", etc/"ssh"
    end

    system "./configure", *args
    system "make"
    ENV.deparallelize
    system "make", "install"

    # This was removed by upstream with very little announcement and has
    # potential to break scripts, so recreate it for now.
    # Debian have done the same thing.
    bin.install_symlink bin/"ssh" => "slogin"

    buildpath.install resource("com.openssh.sshd.sb")
    (etc/"ssh").install "com.openssh.sshd.sb" => "org.openssh.sshd.sb"
  end

  test do
    assert_match "OpenSSH_", shell_output("#{bin}/ssh -V 2>&1")

    port = free_port
    fork { exec sbin/"sshd", "-D", "-p", port.to_s }
    sleep 2
    assert_match "sshd", shell_output("lsof -i :#{port}")
  end
end
__END__
--- configure.orig	2023-09-14 00:32:20.000000000 +0100
+++ configure	2023-09-14 00:33:10.000000000 +0100
@@ -10889,7 +10889,7 @@
 
 	int a=0, b=0, c=0, d=0, n, v;
 	n = sscanf(ZLIB_VERSION, "%d.%d.%d.%d", &a, &b, &c, &d);
-	if (n != 3 && n != 4)
+	if (n < 1)
 		exit(1);
 	v = a*1000000 + b*10000 + c*100 + d;
 	fprintf(stderr, "found zlib version %s (%d)\n", ZLIB_VERSION, v);
