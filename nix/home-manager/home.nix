{ pkgs, ... }: {
  home.username = "jcroft"; 
  home.homeDirectory = "/home/jcroft";
  home.stateVersion = "23.11";
  programs.home-manager.enable = true;
}

