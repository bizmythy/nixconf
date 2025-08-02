{
  lib,
  python3Packages,
  fetchFromGitHub,
  maintainers,
}:
let
  version = "0.2.0";
in
python3Packages.buildPythonPackage {
  pname = "hyprpy";
  inherit version;

  src = fetchFromGitHub {
    owner = "ulinja";
    repo = "hyprpy";
    rev = "v${version}";
    sha256 = lib.fakeHash;
  };

  # Hyprpy has no compiled extensions; no extra native inputs are needed
  nativeBuildInputs = with python3Packages; [ setuptools ];

  meta = with lib; {
    description = "Python bindings for the Hyprland Wayland compositor";
    homepage = "https://github.com/ulinja/hyprpy";
    license = licenses.mit;
    maintainers = [ maintainers.jlobbes ];
  };
}
