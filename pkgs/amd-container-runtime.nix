{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "container-runtime";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "container-toolkit";
    rev = "v${version}";
    sha256 = "sha256-QT5j5c+2zRBmkLFKONXFtgLcKGL0w6UgzcEgpcYAvrI=";
  };

  # Build only the container runtime
  subPackages = [
    "cmd/container-runtime"
  ];

  vendorHash = "sha256-7fVBDz12K/l5H4Vlot4AWs5PsMcjRQVgNbLOfzUqgP0=";

  doCheck = false;

  meta = with lib; {
    description = "AMD Container Toolkit CLI (amd-ctk)";
    homepage = "https://github.com/ROCm/container-toolkit";
    license = licenses.asl20;
    platforms = platforms.linux;
    mainProgram = "container-runtime";
  };
}
