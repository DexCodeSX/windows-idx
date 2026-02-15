{ pkgs, ... }:
{
  packages = with pkgs; [ qemu_full wget ];
  idx.workspace.onStart = {
    run = "bash $HOME/windows-idx/run.sh &";
  };
  env = { QEMU_AUDIO_DRV = "none"; };
}
