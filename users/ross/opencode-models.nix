{
  "qwen3.6:35b-a3b" = {
    display = "Qwen3.6 35B-A3B";
    preset = {
      hf-repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
      hf-file = "Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf";
    };
  };

  "qwen3.6:35b-a3b-mtp" = {
    display = "Qwen3.6 35B-A3B (MTP)";
    preset = {
      hf-repo = "unsloth/Qwen3.6-35B-A3B-MTP-GGUF";
      hf-file = "Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf";
      spec-type = "draft-mtp";
      spec-draft-n-max = 2;
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

  "glm5.2:744b-a40b" = {
    display = "GLM-5.2 744B-A40B";
    preset = {
      hf-repo = "unsloth/GLM-5.2-GGUF";
      # IQ1_S over IQ4_NL for pure decode speed: once threads dropped to 32 the
      # decode is bandwidth-leaning, not overhead-dominated, so reading ~1/4 the
      # bytes per token wins despite the slower scalar dequant (no dotprod kernel
      # for I-quants on this Neoverse-N1). Quality cost is accepted.
      # No MTP: spec-type draft-mtp was a ~5x decode LOSS here on both quants.
      hf-file = "UD-IQ1_S/GLM-5.2-UD-IQ1_S-00001-of-00006.gguf";
    };
  };

  "deepseek-v4-flash:q4" = {
    display = "DeepSeek-V4-Flash 0731";
    preset = {
      # 0731 is the stable release (the non-dated repo is a preview). It only
      # ships Q4_K_XL and Q8_K_XL, no I-quant. Q4_K_XL (~155GB) is the pick over
      # Q8: on a small-active Flash MoE the decode leans on bytes-per-token, so
      # Q4 reads ~half of Q8 and decodes ~2x, and Q4 is high quality already
      # (the "brain damaged" risk is a Q1 problem, not Q4). This spans 2 NUMA
      # nodes (>128GB), so numa=distribute stays correct. Swap the hf-file to
      # UD-Q8_K_XL/...-00001-of-00005.gguf if full precision matters more.
      hf-repo = "unsloth/DeepSeek-V4-Flash-0731-GGUF";
      hf-file = "UD-Q4_K_XL/DeepSeek-V4-Flash-0731-UD-Q4_K_XL-00001-of-00005.gguf";
    };
  };

  "glm4.7-flash:30b-a3b" = {
    display = "GLM-4.7-Flash 30B-A3B";
    preset = {
      # 30B MoE, only ~3.6B active per token (GLM-family twin of the Qwen3.6
      # A3B), so decode flies at ~15 t/s. It stays resident on the GPU, so its
      # ctx and ubatch are capped in the zeta3a llamaModelOverrides (fit is off,
      # the full 135k KV cache does not fit the 12GB card). No MTP: it's a 10x
      # throughput loss on this model per unsloth's own docs, same as GLM-5.2.
      hf-repo = "unsloth/GLM-4.7-Flash-GGUF";
      hf-file = "GLM-4.7-Flash-UD-Q5_K_XL.gguf";
    };
  };
}
