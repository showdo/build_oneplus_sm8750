**`简体中文`** | [English](README-en.md)<br>

[![GitHub](https://img.shields.io/badge/-GitHub|@showdo-181717?logo=github&logoColor=white&style=flat-square)](https://github.com/showdo/build_oneplus_sm8750)
[![Telegram](https://img.shields.io/badge/Telegram-频道-blue.svg?logo=telegram)](https://t.me/qdykernel)
[![酷安|主页](https://img.shields.io/badge/酷安%7C主页-3DDC84?style=flat-square&logo=android&logoColor=white)](http://www.coolapk.com/u/1624571)
[![一加内核开源地址](https://img.shields.io/badge/一加内核开源地址-EB0029?logo=oneplus&logoColor=white&style=flat-square)](https://github.com/OnePlusOSS/kernel_manifest)

### 复刻时如更改项目名，请将下方“使用方法”中的 `build_oneplus_sm8750` 改成你修改后的项目名。

<b>本项目转译自</b>[![GitHub](https://img.shields.io/badge/-GitHub|@HanKuCha-181717?logo=github&logoColor=white&style=flat-square)](https://github.com/HanKuCha/oneplus13_a5p_sukisu)<br>

---

## 使用方法

```bash
git clone https://github.com/showdo/build_oneplus_sm8750.git
```

> ⚠️ 注意：如果你想使用你复刻的项目进行编译，请将上面链接中的 `showdo` 改成你的 GitHub 用户名。  
> 比如你的用户名是 `abcd`，则命令为：  
> `git clone https://github.com/abcd/build_oneplus_sm8750.git`

```bash
cd build_oneplus_sm8750
chmod +x Build_Kernel.sh
./Build_Kernel.sh
```

---

## Windows推荐使用WSL运行  
这里提供WSL迁移到其他盘（如E盘）的方法，避免占用C盘空间。

### WSL2迁移至其他目录步骤

1. 以管理员身份打开 PowerShell，查看当前WSL版本：

```powershell
wsl -l -v
```

2. 停止所有正在运行的WSL实例：

```powershell
wsl --shutdown
```

3. 导出你想迁移的Linux发行版（例如Ubuntu-20.04）：

```powershell
wsl --export Ubuntu-20.04 E:/ubuntu.tar
```

4. 注销原有Linux发行版：

```powershell
wsl --unregister Ubuntu-20.04
```

5. 将导出的发行版导入到新的目录：

```powershell
wsl --import Ubuntu-20.04 E:\ubuntu\ E:\ubuntu.tar --version 2
```

6. 设置默认用户：

```powershell
ubuntu2004.exe config --default-user <username>
```

请将 `<username>` 替换为你WSL的用户名。  
例如我的用户名是 `qiudaoyu`，则命令为：

```powershell
ubuntu2004.exe config --default-user qiudaoyu
```

---

