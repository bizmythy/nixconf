{
  lib,
  python3Packages,
  fetchFromGitHub,
}:
let
  version = "0.2.0";
in
python3Packages.buildPythonPackage {
  pname = "hyprpy";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ulinja";
    repo = "hyprpy";
    rev = "v${version}";
    sha256 = "sha256-b312PmJoVPT5Dt695JdTgDCVlm2LcD0hMmsRUqs3VcQ=";
  };

  build-system = with python3Packages; [ setuptools ];

  dependencies = with python3Packages; [ pydantic ];

  meta = with lib; {
    description = "Python bindings for the Hyprland Wayland compositor";
    homepage = "https://github.com/ulinja/hyprpy";
    license = licenses.mit;
  };
}
