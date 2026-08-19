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
    godot
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
