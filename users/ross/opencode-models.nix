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
}
