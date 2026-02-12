## PTO CPU 仿真验证（CANN 自带头文件）

这个用例使用 `__CPU_SIM` + `pto/common/cpu_stub.hpp`，在纯 CPU 上仿真执行你的 PTO kernel，验证结果是否符合预期。

### 前置

- 已安装 CANN（本机默认路径：`~/miniconda3/envs/cann850/Ascend/cann-8.5.0`）
- 或者提前 `source .../set_env.sh`，让环境变量 `ASCEND_HOME_PATH` 指向 CANN 安装目录

### 一键运行

在本目录下执行：

```bash
bash run.sh
```

成功会输出：

```text
PASS
```

### 校验语义

按 `kernel.cpp` 当前逻辑，`v2` 写回的数据应当与 `v1` 完全一致（`TAND(x, x, x)` 不改变数据）。

---

## Ascend310B 模拟器仿真验证（CA/PV Model）

这个用例使用 CANN 自带 simulator（Ascend310B1）+ ACL host 启动方式，做一次端到端的：

- `ccec` 编译 AICore 二进制
- host 侧加载 `aclrtBinaryLoadFromFile` + `aclrtLaunchKernel`
- 从设备拷回结果并校验（成功输出 `PASS`）

### 一键运行（CA model，精确模型）

```bash
bash run_sim_310b.sh ca
```

### 一键运行（PV model，性能模型）

```bash
bash run_sim_310b.sh pv
```

### 说明

- 默认 SoC：`Ascend310B1`（可用环境变量 `SOC` 覆盖）
- 默认 deviceId：`0`（可用环境变量 `DEVICE_ID` 覆盖）

---

## 批量测试用例（模拟器）

如果你有多组输入/期望输出想在 Ascend310B simulator 上回归验证，可以用脚本：

```bash
bash run_testcases_sim.sh ca testcases
```

### 测试用例格式

默认会扫描 `testcases/<case_name>/`，每个 case 目录下文件约定：

- `v1.bin`：必需，`int32` 小端二进制，形状固定为 `[32,32]`（1024 元素）
- `v2_init.bin`：可选，若不存在则初始化为 `-1`
- `expect_v2.bin`：可选，若不存在则用 CPU 仿真（`__CPU_SIM`）跑一遍生成期望，再用模拟器输出对比

### 常用环境变量

- `SOC`：默认 `Ascend310B1`
- `DEVICE_ID`：默认 `0`
- `CANN` / `ASCEND_HOME_PATH`：CANN 安装目录
- `KERNEL_SYM`：手工指定 kernel 入口符号（检测失败时使用）
- `KERNEL_RE`：用于自动检测符号的正则（默认 `^vec_add_scalar_kernel_2d`）

---

## 新机器快速可复现运行（推荐）

由于 CANN/Simulator 无法随仓库分发，本仓库提供“自检 + 一键运行”脚本，并额外提供 Docker 方案用于固定 host 工具链版本。

### 方式 A：裸机（已安装 CANN）

1) 设置 CANN 路径（两种方式任选其一）：

```bash
export CANN=/path/to/cann
# 或者 export ASCEND_HOME_PATH=/path/to/cann
```

2) 运行环境自检：

```bash
bash scripts/check_env.sh
```

3) 一键跑通（CPU 仿真 + 310B 模拟器）：

```bash
bash scripts/run_all.sh ca
# 或 bash scripts/run_all.sh pv
```

批量用例（可选）：

```bash
bash scripts/run_all.sh ca testcases
```

### 方式 B：Docker（挂载本机 CANN）

Docker 镜像只安装开源工具链；CANN 目录通过 volume 挂载到容器内 `/opt/cann`。

```bash
bash scripts/deploy_test_env.sh --cann /abs/path/to/cann

# 之后可直接运行（会复用 ./.cann_path，不需要再传 --cann）
bash docker/run_docker.sh --mode ca
```
