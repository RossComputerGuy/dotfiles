{
  "qwen3.8-flash-next:125b-a6b" = {
    display = "Qwen3.8-Flash-Next 125B-A6B";
    preset = {
      # Qwen4 hybrid attention with a 51B PLE n-gram table. The table needs at
      # least 4 bits, so Q4_K_XL is the quality floor. 125B total with 6B
      # active keeps decode close to the 35B-A3B it replaces.
      hf-repo = "unsloth/Qwen3.8-Flash-Next-GGUF";
      hf-file = "UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
    };
  };

  "qwen3.6:35b-a3b-heretic" = {
    display = "Qwen3.6 35B-A3B (Heretic)";
    preset = {
      hf-repo = "mradermacher/Qwen3.6-35B-A3B-uncensored-heretic-i1-GGUF";
      hf-file = "Qwen3.6-35B-A3B-uncensored-heretic.i1-Q5_K_M.gguf";
    };
  };

  "ornith1.0:35b" = {
    display = "Ornith1.0 35B";
    preset = {
      hf-repo = "deepreinforce-ai/Ornith-1.0-35B-GGUF";
      hf-file = "ornith-1.0-35b-Q5_K_M.gguf";
    };
  };

  "glm5.3:744b-a40b" = {
    display = "GLM-5.3 744B-A40B";
    preset = {
      # GLM-5.3 uses the GLM-5.2 base, so the gain is post-training only and the
      # quant and decode behaviour carry over. IQ1_S over IQ4_NL for decode
      # speed: at 32 threads decode is bandwidth-bound, so reading about a
      # quarter of the bytes wins despite the slower scalar dequant (this
      # Neoverse-N1 has no dotprod kernel for I-quants). Quality cost is
      # accepted. No MTP: draft-mtp was a 5x decode loss here on both quants.
      hf-repo = "unsloth/GLM-5.3-GGUF";
      hf-file = "UD-IQ1_S/GLM-5.3-UD-IQ1_S-00001-of-00006.gguf";
    };
  };

  "deepseek-v4.1-flash:1017" = {
    display = "DeepSeek-V4.1-Flash 1017";
    preset = {
      # 552B backbone plus a 196B engram and a 1M context. IQ1_S is about
      # 217GiB and keeps 99% of the baseline on Unsloth's benchmarks, so the
      # 512GB machine can drop the old Q4 size tradeoff. This spans two NUMA
      # nodes, so numa=distribute stays correct.
      hf-repo = "unsloth/DeepSeek-V4.1-Flash-1017-GGUF";
      hf-file = "UD-IQ1_S/DeepSeek-V4.1-Flash-1017-UD-IQ1_S-00001-of-00005.gguf";
    };
  };

  "glm4.7-flash:30b-a3b" = {
    display = "GLM-4.7-Flash 30B-A3B";
    preset = {
      # 30B MoE, only ~3.6B active per token (GLM-family twin of the Qwen3.6
      # A3B), so decode flies at ~15 t/s. It stays resident on the GPU, so its
      # ctx and ubatch are capped in the zeta3a llamaModelOverrides (fit is off,
      # the full 135k KV cache does not fit the 12GB card). No MTP: it's a 10x
      # throughput loss on this model per unsloth's own docs, same as GLM-5.3.
      hf-repo = "unsloth/GLM-4.7-Flash-GGUF";
      hf-file = "GLM-4.7-Flash-UD-Q5_K_XL.gguf";
    };
  };
}
