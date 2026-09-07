{
  lib,
  stdenv,
  fetchFromGitHub,
  python312,
  cudaPackages_13,
  addDriverRunpath,
  symlinkJoin,
  callPackage,
  makeWrapper,
  runCommand,
  zlib,
  ninja,
  which,
  numactl,
  tbb,
  rdma-core,
  libfabric,
  openmpi,
  ucx,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:
let
  python = python312;
  cuda = cudaPackages_13;

  # The RTX 5070 is Blackwell, compute capability 12.0. Every architecture list
  # below is necessary, because torch, tvm-ffi and flashinfer each ask the GPU
  # for its capability when the variable is absent, and a build sandbox has no
  # GPU. torch separates with a semicolon, tvm-ffi with a space, so a single
  # value avoids the difference.
  gpuArch = "12.0";

  src = fetchFromGitHub {
    owner = "FlashML-org";
    repo = "FreeToken";
    rev = "9db1a39455a3fb107f3db83e381d10ceadfe5d99"; # v0.1.2
    hash = "sha256-0MhuubuTjNvtQZxisC2cg1dJeR+A6wZ901H5FRv+l+c=";
  };

  # setup.py, tvm-ffi and flashinfer each probe one prefix for bin/nvcc,
  # include/ and lib/. cuda_cudart is a single output here, so join the
  # packages by their bin, dev and lib outputs instead of by name.
  cudaHome = symlinkJoin {
    name = "cuda-home-${cuda.cudaMajorMinorVersion}";
    paths = lib.unique (
      lib.concatMap
        (p: [
          (lib.getBin p)
          (lib.getDev p)
          (lib.getLib p)
        ])
        (
          # cccl, and not cuda_cccl. nixpkgs deprecated the old name.
          with cuda;
          [
            cuda_nvcc
            cuda_cudart
            # cuda_runtime_api.h includes crt/host_defines.h, and the crt
            # headers are a package of their own. Without it every compilation
            # against the CUDA runtime stops at that include. The merged
            # cudatoolkit carries it, but that is a closure of 2.7 GiB and this
            # wrapper keeps CUDA_HOME at run time.
            cuda_crt
            cccl
            cuda_nvrtc
            libcublas
          ]
        )
    );
  };

  # loadWorkspace reads pyproject.toml and uv.lock while Nix evaluates, so the
  # workspace root must be a plain path. That is why pyproject.toml is vendored
  # next to this file: pointing the root at the fetched source would make every
  # evaluation import from a derivation. The root package's src is corrected
  # below, in cudaOverrides.
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

  # "wheel", because no CUDA package in this set has a buildable sdist and
  # "sdist" would try to compile torch from source. Local workspace members
  # ignore this setting and always build from their source tree.
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

  cudaOverrides =
    final: prev:
    let
      sitePackages = final.python.sitePackages;

      # libcuda and libnvidia-ml come from the kernel driver at run time,
      # through the driver link, and are absent from the sandbox by design.
      # Keep this list to these two names. A wildcard would turn every link
      # error into a run-time ImportError that only appears on the GPU machine.
      driverOnly = [
        "libcuda.so.1"
        "libnvidia-ml.so.1"
      ];

      # NVIDIA renames these wheels at each CUDA major version, so match every
      # spelling. Today the unsuffixed names share nvidia/cu13/lib and the
      # names that end in -cu13 each keep their own directory.
      spellings = base: [
        base
        "${base}-cu12"
        "${base}-cu13"
      ];
      bases = [
        "nvidia-cublas"
        "nvidia-cuda-cupti"
        "nvidia-cuda-nvrtc"
        "nvidia-cuda-runtime"
        "nvidia-cudnn"
        "nvidia-cufft"
        "nvidia-cufile"
        "nvidia-curand"
        "nvidia-cusolver"
        "nvidia-cusparse"
        "nvidia-cusparselt"
        "nvidia-nccl"
        "nvidia-nvjitlink"
        "nvidia-nvshmem"
        "nvidia-nvtx"
      ];
      namesIn = someBases: lib.filter (n: builtins.hasAttr n prev) (lib.concatMap spellings someBases);

      # Resolve a cross-reference through final, and not prev, so it names the
      # repaired derivation. Through prev it would build a second, unpatched
      # copy that then fails autopatchelf.
      nvidiaWheels = map (n: final.${n}) (namesIn bases);
      pathsOf = someBases: map (n: final.${n}) (namesIn someBases);

      # addAutoPatchelfSearchPath recurses, so aiming at site-packages covers
      # both CUDA 13 layouts without naming cu13 anywhere.
      searchPaths = lib.concatMapStrings (d: ''
        addAutoPatchelfSearchPath "${d}/${sitePackages}"
      '');

      # Repair one wheel, searching only the paths it is given. The NVIDIA
      # wheels must use this form: giving one of them the whole nvidiaWheels
      # list would put its own output in its own preFixup, and evaluation would
      # not terminate.
      fixWheel =
        extraInputs: extraPaths: drv:
        drv.overrideAttrs (old: {
          # A wheel tagged for a bare linux platform receives no manylinux
          # inputs from uv2nix, so name the C++ runtime here.
          buildInputs =
            (old.buildInputs or [ ])
            ++ [
              stdenv.cc.cc.lib
              zlib
            ]
            ++ extraInputs;
          # appendRunpaths is a plain autoPatchelfHook attribute and needs no
          # entry in nativeBuildInputs.
          appendRunpaths = (old.appendRunpaths or [ ]) ++ [ "${addDriverRunpath.driverLink}/lib" ];
          autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ driverOnly;
          preFixup = (old.preFixup or "") + searchPaths extraPaths;
        });

      # Repair a wheel that consumes the CUDA libraries. Only packages outside
      # the NVIDIA set may use this.
      gpuWheel = extraInputs: extraPaths: fixWheel extraInputs (nvidiaWheels ++ extraPaths);

      forEach =
        someBases: f: lib.listToAttrs (map (n: lib.nameValuePair n (f prev.${n})) (namesIn someBases));

      # The same, for names that carry no CUDA version suffix, so the spellings
      # helper does not apply.
      literal = names: lib.filter (n: builtins.hasAttr n prev) names;
      forNames = names: f: lib.listToAttrs (map (n: lib.nameValuePair n (f prev.${n})) (literal names));
      namedPaths = names: map (n: final.${n}) (literal names);
    in
    # The NVIDIA wheels have edges between themselves, and two of them link
    # fabric libraries. Without these the wheels fail autopatchelf before the
    # build reaches torch.
    forEach [ "nvidia-cufile" ] (fixWheel [ rdma-core ] [ ])
    // forEach [ "nvidia-cusparse" "nvidia-cufft" ] (fixWheel [ ] (pathsOf [ "nvidia-nvjitlink" ]))
    // forEach [ "nvidia-cusolver" ] (
      fixWheel [ ] (pathsOf [
        "nvidia-nvjitlink"
        "nvidia-cusparse"
        "nvidia-cublas"
      ])
    )
    // forEach [ "nvidia-cudnn" ] (fixWheel [ ] (pathsOf [ "nvidia-cublas" ]))
    # The CUTLASS DSL libraries arrive through sglang-kernel and flashinfer.
    # Their profiler opens libcuda, which only the driver provides. The base
    # package is self-contained, and the others read its directory, so name the
    # dependency in one direction only. Pointing each of them at the whole
    # group would put a package in its own search path and evaluation would not
    # terminate.
    // forNames [ "nvidia-cutlass-dsl-libs-base" ] (fixWheel [ ] [ ])
    // forNames [
      "nvidia-cutlass-dsl-libs-core"
      "nvidia-cutlass-dsl-libs-cu12"
      "nvidia-cutlass-dsl-libs-cu13"
    ] (fixWheel [ ] (namedPaths [ "nvidia-cutlass-dsl-libs-base" ]))
    // forEach [ "nvidia-nvshmem" ] (
      fixWheel
        [
          rdma-core
          libfabric
          openmpi
          ucx
        ]
        [ ]
    )
    // {
      torch = gpuWheel [ ] [ ] prev.torch;
      triton = gpuWheel [ ] [ ] prev.triton;
      apache-tvm-ffi = gpuWheel [ ] [ ] prev.apache-tvm-ffi;
      # The wheel declares no requirements of its own but links libtorch, so
      # torch must be named as a search path here.
      sglang-kernel = gpuWheel [ numactl ] [ final.torch ] prev.sglang-kernel;

      # numba opens oneTBB with dlopen, which autoPatchelf cannot infer.
      numba = prev.numba.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ tbb ];
      });

      # The wheel ships a stray top-level build_backend.py, which collides with
      # another wheel while the virtual environment is assembled.
      flashinfer-python = prev.flashinfer-python.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          rm -f $out/${sitePackages}/build_backend.py
        '';
      });

      # modelscope and modelscope-hub both install bin/ms and bin/modelscope,
      # with different contents, and the virtual environment refuses the
      # collision. modelscope is the requirement that FreeToken names, and
      # modelscope-hub is its library, so keep those two commands from the
      # parent. The library keeps bin/modelscope-hub and bin/ms-hub, which are
      # its own names and collide with nothing. FreeToken reaches ModelScope
      # through the Python API, and only when --model-source asks for it, which
      # this machine never does, so no copy of either command is ever run.
      modelscope-hub = prev.modelscope-hub.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          rm -f $out/bin/ms $out/bin/modelscope
        '';
      });

      # The root package. The lock calls it editable and points it at this
      # directory, which holds only the vendored pyproject.toml, so give it the
      # real source here. FreeToken's own [build-system] already requires
      # torch, so uv2nix resolves that and no extra build system is needed.
      freetoken = prev.freetoken.overrideAttrs (old: {
        inherit src;
        # /health answers HTTP 200 in every lifecycle state, loading and error
        # included, and llama-swap reads only the status code. This adds a
        # /healthz route that answers 503 until the engine serves.
        patches = (old.patches or [ ]) ++ [ ./healthz.patch ];

        nativeBuildInputs = old.nativeBuildInputs ++ [
          cudaHome
          ninja
          # torch and flashinfer look for the compiler by running `which nvcc`.
          which
        ];
        buildInputs = (old.buildInputs or [ ]) ++ [ stdenv.cc.cc.lib ];

        env = (old.env or { }) // {
          # tvm-ffi reads CUDA_HOME or CUDA_PATH, so set both.
          CUDA_HOME = "${cudaHome}";
          CUDA_PATH = "${cudaHome}";
          TORCH_CUDA_ARCH_LIST = gpuArch;
          TVM_FFI_CUDA_ARCH_LIST = gpuArch;
        };

        # setup.py imports torch, which loads libtorch_cuda.so, which needs a
        # libcuda.so.1 to resolve against. The CUDA redistributable ships a
        # stub for this case. The test keeps the build working if a later
        # nixpkgs splits that output.
        preBuild = (old.preBuild or "") + ''
          if [ -d "${cuda.cuda_cudart}/lib/stubs" ]; then
            export LD_LIBRARY_PATH="${cuda.cuda_cudart}/lib/stubs''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          fi
        '';

        appendRunpaths = (old.appendRunpaths or [ ]) ++ [ "${addDriverRunpath.driverLink}/lib" ];
        autoPatchelfIgnoreMissingDeps = (old.autoPatchelfIgnoreMissingDeps or [ ]) ++ driverOnly;
      });
    };

  # Order matters. The build systems come first, then the overlay generated
  # from the lock, then the repairs, so the repairs act on real packages.
  pythonSet = (callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      overlay
      cudaOverrides
    ]
  );

  # Ask for the accel extra, and not workspace.deps.default. The default set
  # holds the core requirements only, while flashinfer and sglang-kernel live
  # in the fi and sgl extras that accel collects. With the default set the
  # engine still starts and quietly uses the pure Triton kernels, which is the
  # slow path that this package exists to avoid.
  venv = pythonSet.mkVirtualEnv "freetoken-env" { freetoken = [ "accel" ]; };
in
runCommand "freetoken-0.1.2"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = {
      description = "Edge-native MoE serving engine with OpenAI and Anthropic APIs";
      homepage = "https://github.com/FlashML-org/FreeToken";
      license = lib.licenses.asl20;
      mainProgram = "ft";
      # The CUDA wheels are Linux only, and this is built for one GPU
      # architecture, so no other platform can use it.
      platforms = [ "aarch64-linux" ];
    };
  }
  ''
    mkdir -p $out/bin
    # nvcc stays on PATH because FreeToken compiles a kernel at run time when
    # the prebuilt cache does not cover a variant.
    makeWrapper ${venv}/bin/ft $out/bin/ft \
      --set CUDA_HOME ${cudaHome} \
      --prefix PATH : ${
        lib.makeBinPath [
          cudaHome
          ninja
        ]
      }
  ''
