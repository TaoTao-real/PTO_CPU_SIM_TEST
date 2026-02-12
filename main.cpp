#include <cstdint>
#include <cstdio>
#include <vector>

void vec_add_scalar_kernel_2d(int32_t *v1, int32_t *v2);

int main() {
  constexpr int kRows = 32;
  constexpr int kCols = 32;
  constexpr int kNumel = kRows * kCols;

  std::vector<int32_t> v1(kNumel);
  std::vector<int32_t> v2(kNumel, -1);

  for (int i = 0; i < kNumel; ++i) {
    v1[i] = i * 3 + 7;
  }

  vec_add_scalar_kernel_2d(v1.data(), v2.data());

  for (int i = 0; i < kNumel; ++i) {
    if (v2[i] != v1[i]) {
      std::printf("FAIL at %d: got=%d expect=%d\n", i, v2[i], v1[i]);
      return 1;
    }
  }

  std::puts("PASS");
  return 0;
}

