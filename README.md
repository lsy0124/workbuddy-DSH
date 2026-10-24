# workbuddy-DSH

Windows 下把 WorkBuddy / CodeBuddy 接入 **DSH Desktop** 的完整安装与维护资料：固定版本上游源码、官方 Helper 可执行文件、安装脚本、账号恢复、Helper → DSH 一次性账号同步、图片输入开关、桌面快捷方式，以及这次接入过程中修复问题的记录。

这是集成工具仓库，不是另行实现的模型服务。实际调用链是 **DSH Desktop → dsh-connect-workbuddy → WorkBuddy 上游**；Helper 负责独立账号管理，账号导入是一次性合并，不是持续同步。默认只监听本机，不新增公网反向代理。

## 包含的版本

| 组件 | 版本 | 用途 |
| --- | --- | --- |
| [dingminhua/dsh-connect-workbuddy](https://github.com/dingminhua/dsh-connect-workbuddy) | 4.10.0 | DSH 模型供应商、账号与积分管理 |
| [autumnsentiment/workbuddy-helper](https://github.com/autumnsentiment/workbuddy-helper) | 1.0.8 | 独立账号管理和登录 |
| DSH Desktop | 历史验证内置 host 0.2.0-rc.2 | 目标宿主；不附带商业桌面安装包 |

`vendor/` 保留两份上游完整源码和各自 MIT 许可证。`binaries/WorkBuddyHelper.exe` 是上游 v1.0.8 Windows amd64 官方资产，未做二进制修改。来源提交和校验值见 [依赖清单](dependencies.lock.json)。DSH Desktop、Node.js、Git 等系统软件需另行安装。

## 快速开始

在普通 Windows PowerShell 中执行。使用保存 Helper 账号时的 Windows 用户；受限运行器可能无法访问该用户的 DPAPI 解密能力。

若系统阻止直接执行 `.ps1`，可对单次命令使用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\脚本名称.ps1`，并在其后传入同样参数。仓库根目录的 `.cmd` 入口已采用这种调用方式，不修改系统执行策略。

1. 安装并打开 DSH Desktop 一次。安装插件到实际 Desktop 的 **web profile**，不要把全局 `dsh` CLI 当成 Desktop。

   ```powershell
   .\scripts\Install-Plugin.ps1 -DshExe 'D:\path\DSH Desktop\DSH Desktop.exe'
   ```

   关闭并重新打开 DSH Desktop。此安装方式针对已记录的内嵌 host 布局；宿主升级后如果布局不同，脚本会停止，需根据上游文档重新确认。

2. 启动 Helper 并在页面登录自己的账号。保留终端窗口；也可双击仓库根目录 `Start-Helper.cmd`。

   ```powershell
   .\scripts\Start-Helper.ps1
   ```

   默认页面：<http://127.0.0.1:18080/>。数据默认在 `%LOCALAPPDATA%\WorkBuddyHelper`，凭据存储为 Windows DPAPI 加密的 `state.bin`。

3. Helper 中刷新账号状态，确认正常后，一次性合并国内账号到 DSH。

   ```powershell
   .\scripts\Sync-Accounts.ps1
   ```

   保留已有 DSH 选择，不删除历史账号。同名账号可能对应不同来源记录，脚本不自动去重。若需要切换，用 DSH 自己显示的 ID：

   ```powershell
   .\scripts\Sync-Accounts.ps1 -SelectAccountId '<DSH 中实际存在的账号 ID>'
   ```

   脚本只同步状态为 `confirmed/ready/success/normal` 的账号，跳过需要重新登录的账号。账号状态是筛选条件，不能保证未选择账号的实际授权一定有效；同步后只对**当前选中账号**调用完整登录／积分检查。随后请在 DSH 新建对话发送一个很小的真实请求验证模型调用。

4. 创建桌面快捷方式（正确处理已迁移的 Windows 桌面路径）。

   ```powershell
   .\scripts\New-Shortcuts.ps1 -DshExe 'D:\path\DSH Desktop\DSH Desktop.exe'
   ```

## 账号恢复

备份只应保存在自己电脑，不要上传仓库。创建一个文件夹，把你自己的加密备份命名为 `state.bin`，然后：

```powershell
.\scripts\Restore-Accounts.ps1 -BackupDirectory 'D:\my-private-backup'
.\scripts\Start-Helper.ps1
```

恢复使用 Helper 官方 `--import` 按 UID 合并；先保存当前加密文件副本到 `%LOCALAPPDATA%\WorkBuddyDSH\backups`。遇到其他 Helper 实例会停止，避免并发写入。命令成功后仍需检查 `/api/state` 的真实账号数量。

## 图片输入

```powershell
.\scripts\Set-ImageModels.ps1 -Region cn -ModelIds @('填写实际支持图片的模型 ID')
```

脚本调用插件设置接口，并读回验证。`config/image-models.snapshot.json` 是这次历史配置的无账号快照（国内 20、国际 28 个 ID），**不是官方视觉能力清单，也不代表这些模型都支持图片**。开启开关只是允许附件传入；真正能力取决于上游。

## 目录与说明

- `scripts/`：本仓库维护的通用脚本，未包含任何具体账号 ID 或个人绝对路径。
- `vendor/`：固定上游版本的完整源码，未修改。
- `binaries/`：官方 Helper Windows amd64 可执行文件和校验值。
- `docs/CHANGES.md`：期间的修改、原错误及修正、证据边界。
- `docs/TROUBLESHOOTING.md`：空账号、Failed to fetch、积分横线、失效登录、错误 profile、图片限制。
- `tests/`：脚本语法与时间转换测试、发布文件检查；不会访问真实账号或消耗模型积分。

## 验证边界

历史上已经确认：插件安装在实际 Desktop web profile；Helper 存在五个国内账号；曾通过重新导入新凭据恢复一个选中账号的实时积分查询。最新通用脚本经过静态语法、时间单位和发布内容检查，但**未在另一台干净电脑完成端到端安装，也未在此次整理上传时执行真实模型请求**。本次不声称全部账号已修复或五个账号始终有效。

原始日志、用户截图、账号资料、vault、加密账号备份、真实配置文件和认证 URL 均未收录。上传这些文件即使有加密或脱敏显示，也可能暴露个人数据。

本仓库新增集成脚本与文档以 MIT 发布；上游作品维持自己的版权声明，见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
