# The models FreeToken serves on zeta3a. All three are NVFP4, which the RTX
# 5070 executes natively and llama.cpp cannot read at all.
#
# index fixes the port each model listens on. llama-swap allocates its ${PORT}
# macro in lexicographic model-id order while it loads the configuration, so a
# new id that sorts early would renumber every model after it. A fixed port
# does not move.
#
# args holds only what differs from the ft serve defaults. memory-ratio is the
# one budget knob for the card, and it covers the weights, the MoE expert cache
# and the KV cache together.
{
  "qwen3.8-flash-next:120b" = {
    display = "Qwen3.8-Flash-Next 120B";
    repo = "RadixArk/Qwen3.8-Flash-Next-NVFP4";
    index = 0;
    # This model keeps a 47.7 GiB PLE n-gram table in host RAM. The machine has
    # 510 GiB, so that costs nothing here.
    args = [ "--memory-ratio 0.85" ];
  };

  "glm5.3-flash:169b" = {
    display = "GLM-5.3-Flash 169B";
    repo = "RedHatAI/GLM-5.3-Flash-NVFP4";
    index = 1;
    args = [ "--memory-ratio 0.85" ];
  };

  "deepseek-v4-flash:nvfp4" = {
    display = "DeepSeek-V4-Flash 0731";
    repo = "nvidia/DeepSeek-V4-Flash-0731-NVFP4";
    index = 2;
    # Do not add --page-size. DeepSeek-V4 sets its own page size of 128.
    #
    # This is the only NVFP4 quantisation of the 0731 release that keeps the
    # inference/ directory. FreeToken reads the authoritative model arguments
    # from inference/config.json, so a quantisation that removes that directory
    # does not load. Most third-party quantisations remove it.
    args = [ "--memory-ratio 0.85" ];
  };
}
