# 采样壁纸指定屏幕区域的亮度 -> 判断玻璃上的文字该用深色还是浅色
# 用法:
#   python sample_wallpaper_luma.py                 # 底部条带 (任务栏)
#   python sample_wallpaper_luma.py --rect x1,y1,x2,y2   # 指定物理屏幕区域 (如开始菜单)
# 原理: v8 玻璃近乎全透 (tint 仅 +12% 白), 玻璃背后的亮度 ≈ 壁纸该区域的亮度
import ctypes
import os
import sys
import winreg

from PIL import Image


def screen_size():
    ctypes.windll.user32.SetProcessDPIAware()
    user32 = ctypes.windll.user32
    return user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)


def wallpaper_path():
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r'Control Panel\Desktop') as k:
        p, _ = winreg.QueryValueEx(k, 'Wallpaper')
    if os.path.isfile(p):
        return p
    # 注册表值失效时退回系统转码缓存
    t = os.path.expandvars(r'%APPDATA%\Microsoft\Windows\Themes\TranscodedWallpaper')
    return t if os.path.isfile(t) else p


def main():
    rect = None
    args = sys.argv[1:]
    if '--rect' in args:
        i = args.index('--rect')
        rect = tuple(int(v) for v in args[i + 1].split(','))
        if len(rect) != 4:
            raise SystemExit('--rect needs x1,y1,x2,y2')
    sw, sh = screen_size()
    path = wallpaper_path()
    img = Image.open(path).convert('RGB')
    W, H = img.size
    # 模拟 Windows "Fill" 显示: 缩放到完全覆盖屏幕, 居中裁剪
    cropW = min(W, max(1, int(H * sw / sh + 0.5)))
    cropH = min(H, max(1, int(W * sh / sw + 0.5)))
    left = (W - cropW) // 2
    top = (H - cropH) // 2
    filled = img.crop((left, top, left + cropW, top + cropH))
    if rect:
        # 物理屏幕坐标 -> Fill 裁剪图坐标
        sx1, sy1, sx2, sy2 = rect
        fx1 = max(0, min(cropW - 1, int(cropW * sx1 / sw)))
        fy1 = max(0, min(cropH - 1, int(cropH * sy1 / sh)))
        fx2 = max(fx1 + 1, min(cropW, int(cropW * sx2 / sw)))
        fy2 = max(fy1 + 1, min(cropH, int(cropH * sy2 / sh)))
        region = filled.crop((fx1, fy1, fx2, fy2)).resize((64, 64))
        label = 'rect %d,%d,%d,%d' % rect
    else:
        # 底部任务栏条带 (物理 60px 占屏比)
        bandH = max(1, int(cropH * 60 / sh))
        region = filled.crop((0, filled.height - bandH, filled.width, filled.height)).resize((64, 8))
        label = 'bottom-strip'
    px = list(region.getdata())
    luma = sum(0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in px) / len(px) / 255
    print('wallpaper: %s (%dx%d)' % (path, W, H))
    print('screen %dx%d -> %s' % (sw, sh, label))
    print('luma = %.3f  (0=黑 1=白, 阈值 0.5)' % luma)
    print('=> %s' % ('亮 -> 玻璃上用深色字' if luma > 0.5 else '暗 -> 玻璃上用浅色字'))


if __name__ == '__main__':
    main()
