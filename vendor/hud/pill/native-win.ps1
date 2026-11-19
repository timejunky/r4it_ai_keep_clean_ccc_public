# Copyright (c) 2026 ready-4-it
# pill/native-win.ps1 — CccHudWin P/Invoke surface (one job: native window helpers).
# Dot-sourced from winforms-pill.ps1 after Write-PidFile exists.

# Claim pid before CccHudWin Add-Type so Control Center waitForPidFile succeeds
# while WinForms is still compiling (pause/restart used to time out here).
Write-PidFile
Write-HudBoot "pid claimed early pid=$PID"

try {
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class CccHudWin {
  public static readonly IntPtr HWND_TOP = IntPtr.Zero;
  public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
  public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
  public const uint SWP_NOSIZE = 0x0001;
  public const uint SWP_NOMOVE = 0x0002;
  public const uint SWP_NOZORDER = 0x0004;
  public const uint SWP_NOACTIVATE = 0x0010;
  public const uint SWP_SHOWWINDOW = 0x0040;
  public const int GWL_EXSTYLE = -20;
  public const int GWLP_HWNDPARENT = -8;
  public const int WS_EX_LAYERED = 0x80000;
  public const int WS_EX_TOOLWINDOW = 0x00000080;
  public const int WS_EX_TOPMOST = 0x00000008;
  public const int WS_EX_NOACTIVATE = 0x08000000;
  public const int SW_HIDE = 0;
  public const int SW_SHOWNOACTIVATE = 4;

  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
  [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")] public static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
  [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")] public static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);
  [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr hWnd);

  // GetWindowText sends WM_GETTEXT and never returns if that thread is Not Responding.
  // A hung Antigravity window then freezes the pill tick, so VS Code Agents is never docked.
  public static string WindowTitle(IntPtr hwnd) {
    if (hwnd == IntPtr.Zero) return "";
    try { if (IsHungAppWindow(hwnd)) return ""; } catch { }
    var sb = new StringBuilder(512);
    GetWindowText(hwnd, sb, 512);
    return sb.ToString();
  }
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, int dwAttribute, out RECT pvAttribute, int cbAttribute);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);
  public const uint GA_ROOT = 2;
  public const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;

  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

  public static bool GetVisibleWindowRect(IntPtr hWnd, out RECT lpRect) {
    lpRect = new RECT();
    if (hWnd == IntPtr.Zero) return false;
    try {
      RECT dwm;
      if (DwmGetWindowAttribute(hWnd, DWMWA_EXTENDED_FRAME_BOUNDS, out dwm, Marshal.SizeOf(typeof(RECT))) == 0) {
        if (dwm.Right > dwm.Left && dwm.Bottom > dwm.Top) { lpRect = dwm; return true; }
      }
    } catch { }
    return GetWindowRect(hWnd, out lpRect);
  }

  public static IntPtr GetWindowLongPtrCompat(IntPtr hWnd, int nIndex) {
    if (IntPtr.Size == 8) return GetWindowLongPtr64(hWnd, nIndex);
    return new IntPtr(GetWindowLong(hWnd, nIndex));
  }
  public static IntPtr SetWindowLongPtrCompat(IntPtr hWnd, int nIndex, IntPtr dwNewLong) {
    if (IntPtr.Size == 8) return SetWindowLongPtr64(hWnd, nIndex, dwNewLong);
    return new IntPtr(SetWindowLong(hWnd, nIndex, dwNewLong.ToInt32()));
  }
  public static void MakeNoActivateToolWindow(IntPtr hwnd) {
    int ex = GetWindowLong(hwnd, GWL_EXSTYLE);
    ex = (ex | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE) & ~WS_EX_TOPMOST;
    SetWindowLong(hwnd, GWL_EXSTYLE, ex);
    SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  }
  public static IntPtr RootWindow(IntPtr hwnd) {
    if (hwnd == IntPtr.Zero) return IntPtr.Zero;
    IntPtr root = GetAncestor(hwnd, GA_ROOT);
    return root != IntPtr.Zero ? root : hwnd;
  }
  public static bool SetOwner(IntPtr hwnd, IntPtr ownerHwnd) {
    if (hwnd == IntPtr.Zero || ownerHwnd == IntPtr.Zero) return false;
    IntPtr cur = GetWindowLongPtrCompat(hwnd, GWLP_HWNDPARENT);
    if (cur == ownerHwnd) return true;
    if (cur != IntPtr.Zero) {
      SetWindowLongPtrCompat(hwnd, GWLP_HWNDPARENT, IntPtr.Zero);
    }
    SetWindowLongPtrCompat(hwnd, GWLP_HWNDPARENT, ownerHwnd);
    return GetWindowLongPtrCompat(hwnd, GWLP_HWNDPARENT) == ownerHwnd;
  }
  public static void ClearOwner(IntPtr hwnd) {
    if (hwnd == IntPtr.Zero) return;
    SetWindowLongPtrCompat(hwnd, GWLP_HWNDPARENT, IntPtr.Zero);
  }
  public static void RaiseAboveOwner(IntPtr hwnd) {
    SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }
  public static void ShowUnownedTopMost(IntPtr hwnd) {
    if (hwnd == IntPtr.Zero) return;
    SetWindowLongPtrCompat(hwnd, GWLP_HWNDPARENT, IntPtr.Zero);
    SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }
  public static void ClearUnownedTopMost(IntPtr hwnd) {
    if (hwnd == IntPtr.Zero) return;
    SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }
  public static void MoveNoActivate(IntPtr hwnd, int x, int y) {
    if (hwnd == IntPtr.Zero) return;
    SetWindowPos(hwnd, IntPtr.Zero, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  }
  public static void SizeNoActivate(IntPtr hwnd, int w, int h) {
    if (hwnd == IntPtr.Zero) return;
    SetWindowPos(hwnd, IntPtr.Zero, 0, 0, w, h, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  }
  public static void ShowNoActivate(IntPtr hwnd) {
    if (hwnd == IntPtr.Zero) return;
    ShowWindow(hwnd, SW_SHOWNOACTIVATE);
  }
  public static void HideNoActivate(IntPtr hwnd) {
    if (hwnd == IntPtr.Zero) return;
    ShowWindow(hwnd, SW_HIDE);
  }
  public static string ForegroundTitle() {
    IntPtr h = RootWindow(GetForegroundWindow());
    return WindowTitle(h);
  }
}
"@
  Write-HudBoot 'CccHudWin Add-Type ok'
} catch {
  Write-HudBoot ("CccHudWin Add-Type FAIL: " + $_.Exception.Message)
  exit 1
}
