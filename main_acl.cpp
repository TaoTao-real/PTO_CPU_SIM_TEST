#include <acl/acl.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

static void CheckAcl(aclError err, const char *what) {
  if (err == ACL_SUCCESS) {
    return;
  }
  const char *recent = aclGetRecentErrMsg();
  if (recent == nullptr) {
    recent = "(null)";
  }
  std::fprintf(stderr, "%s failed, err=%d, recent=%s\n", what, static_cast<int>(err), recent);
  std::exit(1);
}

struct KernelArgs {
  void *v1;
  void *v2;
};

int main(int argc, char **argv) {
  const char *binPath = (argc > 1) ? argv[1] : "vec_add_310b.o";
  const char *kernelName = (argc > 2) ? argv[2] : "vec_add_scalar_kernel_2d__kernel0";
  int deviceId = (argc > 3) ? std::atoi(argv[3]) : 0;

  CheckAcl(aclInit(nullptr), "aclInit");
  CheckAcl(aclrtSetDevice(deviceId), "aclrtSetDevice");

  aclrtContext ctx = nullptr;
  CheckAcl(aclrtCreateContext(&ctx, deviceId), "aclrtCreateContext");

  aclrtStream stream = nullptr;
  CheckAcl(aclrtCreateStream(&stream), "aclrtCreateStream");

  constexpr int kRows = 32;
  constexpr int kCols = 32;
  constexpr int kNumel = kRows * kCols;
  const size_t bytes = static_cast<size_t>(kNumel) * sizeof(int32_t);

  std::vector<int32_t> host_v1(kNumel);
  std::vector<int32_t> host_v2(kNumel, -1);
  for (int i = 0; i < kNumel; ++i) {
    host_v1[i] = i * 3 + 7;
  }

  void *dev_v1 = nullptr;
  void *dev_v2 = nullptr;
  CheckAcl(aclrtMalloc(&dev_v1, bytes, ACL_MEM_MALLOC_NORMAL_ONLY), "aclrtMalloc v1");
  CheckAcl(aclrtMalloc(&dev_v2, bytes, ACL_MEM_MALLOC_NORMAL_ONLY), "aclrtMalloc v2");

  CheckAcl(aclrtMemcpy(dev_v1, bytes, host_v1.data(), bytes, ACL_MEMCPY_HOST_TO_DEVICE), "H2D v1");
  CheckAcl(aclrtMemcpy(dev_v2, bytes, host_v2.data(), bytes, ACL_MEMCPY_HOST_TO_DEVICE), "H2D v2");

  aclrtBinaryLoadOptions opts;
  opts.options = nullptr;
  opts.numOpt = 0;

  aclrtBinHandle binHandle = nullptr;
  CheckAcl(aclrtBinaryLoadFromFile(binPath, &opts, &binHandle), "aclrtBinaryLoadFromFile");

  aclrtFuncHandle funcHandle = nullptr;
  CheckAcl(aclrtBinaryGetFunction(binHandle, kernelName, &funcHandle), "aclrtBinaryGetFunction");

  KernelArgs args{dev_v1, dev_v2};

  // This kernel uses fixed indexing (v4=0) and is expected to run with one block.
  CheckAcl(aclrtLaunchKernel(funcHandle, 1, &args, sizeof(args), stream), "aclrtLaunchKernel");
  CheckAcl(aclrtSynchronizeStream(stream), "aclrtSynchronizeStream");

  CheckAcl(aclrtMemcpy(host_v2.data(), bytes, dev_v2, bytes, ACL_MEMCPY_DEVICE_TO_HOST), "D2H v2");

  for (int i = 0; i < kNumel; ++i) {
    if (host_v2[i] != host_v1[i]) {
      std::printf("FAIL at %d: got=%d expect=%d\n", i, host_v2[i], host_v1[i]);
      return 1;
    }
  }

  std::puts("PASS");

  (void)aclrtBinaryUnLoad(binHandle);
  (void)aclrtFree(dev_v2);
  (void)aclrtFree(dev_v1);
  (void)aclrtDestroyStream(stream);
  (void)aclrtDestroyContext(ctx);
  (void)aclrtResetDevice(deviceId);
  (void)aclFinalize();
  return 0;
}

