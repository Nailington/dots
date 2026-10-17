{ pkgs, ... }:

{
  home.packages = with pkgs; [
    krita
    inkscape
    blender
    aseprite
    gpu-screen-recorder
    gpu-screen-recorder-gtk
    unityhub
    # Godot 4.7 requires harfbuzz-vector; nixpkgs currently leaves it disabled.
    (godot.override {
      harfbuzz = pkgs.harfbuzz.override { withVector = true; };
    })
  ];

  programs.obs-studio = {
    enable = true;
    package = (
      pkgs.obs-studio.override {
        cudaSupport = true;
      }
    );
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
    ];
  };
}
