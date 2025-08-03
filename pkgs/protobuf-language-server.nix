{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "protobuf-language-server";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "lasorda";
    repo = "protobuf-language-server";
    rev = "v${version}";
    hash = "sha256-bDsvByXa2kH3DnvQpAq79XvwFg4gfhtOP2BpqA1LCI0=";
  };

  vendorHash = "sha256-dRria1zm5Jk7ScXh0HXeU686EmZcRrz5ZgnF0ca9aUQ=";

  # TestMethodsGen overwrites go-lsp/lsp/methods_gen.go with missing imports.
  # This causes other tests to break.
  checkFlags = [ "-skip=TestMethodsGen" ];

  meta = with lib; {
    description = "A language server implementation for Google Protocol Buffers";
    homepage = "https://github.com/protocolbuffers/protobuf-language-server";
    license = licenses.asl20;
    maintainers = with maintainers; [ bizmyth ];
  };
}
