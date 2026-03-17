import ctypes, time, pyautogui, sys
pyautogui.FAILSAFE = False
user32 = ctypes.windll.user32

# Wait for terminal to settle
time.sleep(2)

# Find InPrivate Edge window
EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_ulong, ctypes.c_ulong)
target_hwnd = None

def find_window(hwnd, lParam):
    global target_hwnd
    if user32.IsWindowVisible(hwnd):
        length = user32.GetWindowTextLengthW(hwnd)
        if length > 0:
            buf = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buf, length + 1)
            if 'InPrivate' in buf.value:
                target_hwnd = hwnd
    return True

user32.EnumWindows(EnumWindowsProc(find_window), 0)

if not target_hwnd:
    with open('C:\\temp\\tamresearch1\\script-result.txt', 'w') as f:
        f.write('ERROR: No InPrivate window found')
    sys.exit(1)

# Aggressively bring Edge to front
for i in range(3):
    user32.keybd_event(0x12, 0, 0, 0)
    time.sleep(0.05)
    user32.ShowWindow(target_hwnd, 9)
    result = user32.SetForegroundWindow(target_hwnd)
    time.sleep(0.05)
    user32.keybd_event(0x12, 0, 2, 0)
    time.sleep(0.3)

# Extra wait to ensure Edge is truly in front
time.sleep(1)

# Click on the email field
pyautogui.click(726, 392)
time.sleep(0.5)
pyautogui.click(726, 392)
time.sleep(0.3)

# Type email
pyautogui.write('td-squad-ai-team@outlook.com', interval=0.04)
time.sleep(0.5)

# Screenshot
img = pyautogui.screenshot()
img.save('C:\\temp\\tamresearch1\\script-result.png')

with open('C:\\temp\\tamresearch1\\script-result.txt', 'w') as f:
    f.write('SUCCESS')
