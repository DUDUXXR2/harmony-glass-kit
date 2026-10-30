# Harmony Glass 材质定案与操作手册

> 单源定义：`material.json` ｜ 应用器：`recipes\apply_material.ps1`（v3，默认热重载）
> 更新：2026-10-29（材质 v8 + 热重载机制验证）

## 当前材质 v8（用户确认观感）

| 参数 | 值 | 参考依据（HarmonyOSLiquidGlass 实测值） |
|---|---|---|
| BlurAmount | 8 | 华为底板 blurRadius=0.3dp（近零模糊）；Dialog 3dp；>12 会回到浑浊亚克力感 |
| tintColor | #FFF5F8FC | Dialog surfaceColor (0.96, 0.97, 1.00) |
| tintOpacity | 0.12 | Dialog surfaceAlpha 0.17 区间 |
| tintLuminosityOpacity | 0.05 | — |
| tintSaturation | 1.35 | Dialog vibrancy 1.35 |
| 任务栏几何 | 贴底全宽、无圆角（PillR=0） | 华为底栏不悬浮、下方跟 Windows 一样 |
| 假高光 | 上下双缘 1.2px：顶 #96EAF6FF（冰白镜面 59%）/ 底 #4DFFFFFF（白背光 30%） | 参考公式 |dot(n,45°光向)|≈0.707 上下对称；环境光只照 dl>0 半边 |
| 圆角 | panel 16 / element 10 | — |

**设计原理**：华为液态玻璃 = 近零模糊 + 高透射 + 强边缘折射。WindhawkBlur 引擎能力边界 = 单高斯（无背景采样位移），真折射需自定义 C++ mod（DComp + Win2D DisplacementMap）。当前用「上下双缘高光线」近似，用户已接受。

## 操作

```bash
# 改材质：编辑 material.json → 管理员运行（默认热重载，秒级生效，不重启 explorer）
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-File','E:\A个人\HarmonyGlass\recipes\apply_material.ps1' -Wait"

# 强制完整重启（材质大改/几何变更时）
#   apply_material.ps1 加参数 -Restart

# 截图验证（DPI-aware，物理 2560×1440）
powershell -File recipes\capture_dpi.ps1 -Tag xxx
powershell -File recipes\capture_panels_v2.ps1 -Tag xxx   # Win+A / Win+N 面板
```

## 热重载机制（2026-10-29 实测验证）

写 styler 注册表设置 + bump mod 根键 `SettingsChangeTime`（DWORD, Unix 秒）→ **不重启 explorer**，约 8 秒内样式刷新。

- 机理：taskbar styler 源码 L9760 / NC styler L5389 的 `Wh_ModSettingsChanged` 在宿主窗口线程内重载样式
- 验证：红时钟规则 → 8 秒后截图 1043 红像素命中（explorer 全程存活）
- **重要**：引擎读规则按连续槽位 `for(i=0;;i++)`，遇第一个空 target 即停。规则必须写连续索引；跳槽写 = 静默不读（此前索引 40 测试作废的原因）

## 引擎规则（读 Windhawk mod 源码确认）

1. **常量前缀匹配、先到先得**：styleConstants 名字互为前缀会错配（GlassBlur/GlassLite 命名规避了这点）
2. **整组丢弃**：一个 target 的全部 styles 打包成一个 XAML Style，任一 setter 解析失败 → 该 target 全部样式静默丢弃（无报错）
3. `WindhawkBlur` 仅支持：BlurAmount / TintColor / TintOpacity / TintLuminosityOpacity / TintSaturation / NoiseOpacity / NoiseDensity（无 FallbackColor）
4. isXamlValue：属性名以 `:` 结尾触发
5. 文字色可改：官方主题用 `Foreground=`（如 `TextBlock#TimeInnerTextBlock`）——文字自适应的落点
6. NC 宿主（ShellExperienceHost / ShellHost）不随 explorer 重启

## 平台陷阱（全部实测踩坑）

| # | 陷阱 | 对策 |
|---|---|---|
| 1 | PS 5.1 读无 BOM UTF-8 当 ANSI → 中文乱码破坏 param() | 所有 .ps1/.json 一律 UTF-8 **BOM** |
| 2 | 2560×1440 物理 @125% 缩放，DPI-unaware 截图只抓 80% 左上 | 截图前 `SetProcessDPIAware()` |
| 3 | 游戏全屏时截图 = 游戏画面 | 测试前确认桌面可见 |
| 4 | 面板宿主被杀后首次打开要 4s+ 渲染 | 截图时机留足等待 |
| 5 | `MkGlass $x -replace …` 的 -replace 被当函数位置参数 | 避免该写法 |
| 6 | **`-like 'name[24]*'` 方括号=通配字符类，永不匹配字面值名**（首次 cleanup 因此空操作，红残留数小时） | 注册表值名精确删除一律用 `.StartsWith('controlStyles[24]')` |

## 窗口材质路线结论（2026-10-29 实测）

| 路线 | 效果 | 可调参数 | 持久性 |
|---|---|---|---|
| DWM backdrop 38=3（系统 Acrylic 预设） | ✅ 强通透（红光带/山形全透） | ❌ 固定配方（模糊/浓度/色调全不可调） | **按窗口一次性**，新开窗口不继承 |
| accent API（`SetWindowCompositionAttribute` WCA_ACCENT_POLICY state 4） | ✅ 通透+自定义 tint | ✅ tint 颜色+alpha 可调（AABBGGRR）；❌ 模糊半径固定，无 luminosity/saturation | 同上，按窗口一次性 |

**关键陷阱（实测踩坑）**：`DwmSetWindowAttribute` 只对调用时存活的窗口生效——**新开的窗口不继承**。「设了没变化」多半是开了新窗口，用 `get_backdrop.ps1` 读回验证（backdrop=1 None / 2 Mica / 3 Acrylic / 4 Mica-Alt）。

**与任务栏 v8 的差距 = 平台级限制**：任务栏玻璃是 XAML composition 内的 `WindhawkBlur`（BlurAmount/TintOpacity/TintSaturation/TintLuminosityOpacity 全可调）；普通窗口走 DWM 预设或 accent API，两条路都不暴露模糊半径/饱和度/明度。**窗口做到 100% v8 同款不可行**，accent 自定义 tint（`1FFCF8F5` ≈ v8 的 12% tint）是最接近的近似。

| 窗口 | 结论 |
|---|---|
| 资源管理器 (CabinetWClass) | ✅ 两条路线均成立（backdrop 3 / accent 4） |
| Claude (Electron/Chromium) | ❌ 均不成立——Chromium 不透明合成层盖住一切 DWM 侧效果（backdrop 与 accent 同层，都会被盖） |

用法（已验证）：
```bash
powershell -File recipes\set_backdrop.ps1 explorer 3 CabinetWClass      # 系统 Acrylic 预设
powershell -File recipes\get_backdrop.ps1 explorer CabinetWClass        # 读回验证
powershell -File recipes\set_accent.ps1 -Hwnd 0x123 -TintHex 1FFCF8F5   # accent 自定义 tint (12% v8 配方)
powershell -File recipes\set_accent.ps1 -Hwnd 0x123 -State 0            # 重置
```

## 开始菜单文字自动反色（2026-10-29 实测生效）

**机制**：`apply_text_contrast.ps1`（提权运行）→ 采样壁纸**开始菜单所在屏幕区域**亮度（`sample_wallpaper_luma.py --rect`）→ luma > 0.5 深色字 / ≤ 0.5 白字 → 写 `controlStyles[10-17]`（`Foreground=White` / `#FF1A1A1A`，8 个官方主题同款 TextBlock）→ bump 热重载。

```bash
# 自动模式（采样壁纸决定）——已验证: 暗壁纸 luma 0.407 → 白字, 白像素 0→3561
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-File','E:\A个人\HarmonyGlass\recipes\apply_text_contrast.ps1','-Mode','auto' -Wait"
# 强制白字 / 深字 / 关闭: -Mode dark | light | off
```

**注意**：auto 是**运行时采样**——换壁纸后需重跑一次脚本才跟随。壁纸变更自动跟随的监视器脚本已写好（`watch_wallpaper.ps1`，30s 轮询壁纸哈希，变更自动重跑反色），但**登录计划任务尚未注册**（需要用户明确同意常驻后台）；手动启用：
```bash
powershell -Command "Register-ScheduledTask -TaskName 'HarmonyGlass\TextContrast' -Action (New-ScheduledTaskAction -Execute powershell.exe -Argument '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File E:\A个人\HarmonyGlass\recipes\watch_wallpaper.ps1') -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)) -Force"
```

**v1 方案教训（已废弃）**：`themeResourceVariables` 的 `Key={ThemeResource Key}` 是自引用空操作（引擎 L10131 TryLookup 找到后把值又指回自己）。真正有效的系统文字资源覆盖应该用具体色值或跨主题资源引用；本项目改用 controlStyles Foreground 规则，简单直接。

## 待办（下次会话）

1. 资源管理器玻璃**常驻方案**：写 Windhawk mod（钩窗口创建事件）对新建 CabinetWClass 自动设 backdrop/accent——当前 PS 脚本一次性，新窗口不继承
2. **壁纸变更自动跟随**：注册 WMI 事件或定时器监听 `TranscodedWallpaper` 变化 → 自动重跑 apply_text_contrast（换壁纸后文字自动反色）
3. 媒体卡 / 托盘溢出 / 跳转列表截图验收
4. 上下缘高光线按用户反馈调优
5. Electron 窗口玻璃化（Claude）：需 mica-for-everyone 类 mod 或 Electron backdropMaterial，DWM/accent 两条路都被 Chromium 层盖死
