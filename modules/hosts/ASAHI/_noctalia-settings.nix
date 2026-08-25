# ASAHI's Noctalia settings: the full set from hm-v3 config/noctalia.nix.
#
# Plain data file; the `_` prefix keeps import-tree from auto-importing it
# (same convention as features/nvf/_*.nix) — asahiConfiguration imports it
# explicitly into programs.noctalia.settings.
#
# Adaptations vs hm-v3 (everything else verbatim):
# - appLauncher.terminalCommand: alacritty is not installed here; ghostty is
#   (and ghostty accepts `-e` per its CLI).
{
  settingsVersion = 0;
  bar = {
    barType = "simple";
    position = "top";
    monitors = [ ];
    density = "default";
    showOutline = false;
    showCapsule = false;
    capsuleOpacity = 1;
    capsuleColorKey = "none";
    widgetSpacing = 6;
    contentPadding = 14;
    fontScale = 1;
    enableExclusionZoneInset = true;
    backgroundOpacity = 0.93;
    useSeparateOpacity = false;
    marginVertical = 4;
    marginHorizontal = 4;
    frameThickness = 8;
    frameRadius = 12;
    outerCorners = true;
    hideOnOverview = false;
    displayMode = "always_visible";
    autoHideDelay = 500;
    autoShowDelay = 150;
    showOnWorkspaceSwitch = true;
    widgets = {
      left = [
        { id = "MediaMini"; }
        { id = "Workspace"; }
      ];
      center = [
        "clock"
        "spacer_2"
        "settings"
      ];
      start = [
        "media"
        "workspaces"
      ];
      end = [
        "tray"
        "notifications"
        "clipboard"
        "network"
        "bluetooth"
        "volume"
        "brightness"
        "sysmon"
        "battery"
        "session"
      ];
      thickness = 32;
      right = [
        { id = "Tray"; }
        { id = "NotificationHistory"; }
        { id = "Network"; }
        { id = "Bluetooth"; }
        { id = "Volume"; }
        { id = "Brightness"; }
        { id = "SystemMonitor"; }
        { id = "Battery"; }
        { id = "SessionMenu"; }
      ];
    };
    mouseWheelAction = "none";
    reverseScroll = false;
    mouseWheelWrap = true;
    middleClickAction = "none";
    middleClickFollowMouse = false;
    middleClickCommand = "";
    rightClickAction = "controlCenter";
    rightClickFollowMouse = true;
    rightClickCommand = "";
    screenOverrides = [ ];
  };

  widget = {
    audio_visualizer = {
      width = 8;
    };
    spacer_2 = {
      anchor = true;
      length = 296;
      scale = 0.65;
      type = "spacer";
    };
  };

  general = {
    avatarImage = "";
    dimmerOpacity = 0.2;
    showScreenCorners = false;
    forceBlackScreenCorners = false;
    scaleRatio = 1;
    radiusRatio = 1;
    iRadiusRatio = 1;
    boxRadiusRatio = 1;
    screenRadiusRatio = 1;
    animationSpeed = 1;
    animationDisabled = false;
    compactLockScreen = false;
    lockScreenAnimations = false;
    lockOnSuspend = true;
    showSessionButtonsOnLockScreen = true;
    showHibernateOnLockScreen = false;
    enableLockScreenMediaControls = false;
    enableShadows = true;
    enableBlurBehind = true;
    shadowDirection = "bottom_right";
    shadowOffsetX = 2;
    shadowOffsetY = 3;
    language = "";
    allowPanelsOnScreenWithoutBar = true;
    showChangelogOnStartup = true;
    telemetryEnabled = false;
    enableLockScreenCountdown = true;
    lockScreenCountdownDuration = 10000;
    autoStartAuth = false;
    allowPasswordWithFprintd = false;
    clockStyle = "custom";
    clockFormat = "hh\nmm";
    passwordChars = false;
    lockScreenMonitors = [ ];
    lockScreenBlur = 0.5;
    lockScreenTint = 0.3;
    keybinds = {
      keyUp = [ "Up" ];
      keyDown = [ "Down" ];
      keyLeft = [ "Left" ];
      keyRight = [ "Right" ];
      keyEnter = [
        "Return"
        "Enter"
      ];
      keyEscape = [ "Esc" ];
      keyRemove = [ "Del" ];
    };
    reverseScroll = false;
    smoothScrollEnabled = true;
  };

  ui = {
    fontDefault = "";
    fontFixed = "";
    fontDefaultScale = 1;
    fontFixedScale = 1;
    tooltipsEnabled = true;
    scrollbarAlwaysVisible = true;
    boxBorderEnabled = false;
    panelBackgroundOpacity = 0.93;
    translucentWidgets = false;
    panelsAttachedToBar = true;
    settingsPanelMode = "attached";
    settingsPanelSideBarCardStyle = false;
  };

  location = {
    name = "";
    weatherEnabled = true;
    weatherShowEffects = true;
    weatherTaliaMascotAlways = false;
    useFahrenheit = false;
    use12hourFormat = false;
    showWeekNumberInCalendar = false;
    showCalendarEvents = true;
    showCalendarWeather = true;
    analogClockInCalendar = false;
    firstDayOfWeek = -1;
    hideWeatherTimezone = false;
    hideWeatherCityName = false;
    autoLocate = false;
  };

  calendar = {
    cards = [
      {
        enabled = true;
        id = "calendar-header-card";
      }
      {
        enabled = true;
        id = "calendar-month-card";
      }
      {
        enabled = true;
        id = "weather-card";
      }
    ];
  };

  controlCenter = {
    position = "close_to_bar_button";
    diskPath = "/";
    shortcuts = {
      left = [
        { id = "Network"; }
        { id = "Bluetooth"; }
        { id = "WallpaperSelector"; }
        { id = "NoctaliaPerformance"; }
      ];
      right = [
        { id = "Notifications"; }
        { id = "PowerProfile"; }
        { id = "KeepAwake"; }
        { id = "NightLight"; }
      ];
    };
    cards = [
      {
        enabled = true;
        id = "profile-card";
      }
      {
        enabled = true;
        id = "shortcuts-card";
      }
      {
        enabled = true;
        id = "audio-card";
      }
      {
        enabled = false;
        id = "brightness-card";
      }
      {
        enabled = true;
        id = "weather-card";
      }
      {
        enabled = true;
        id = "media-sysmon-card";
      }
    ];
  };

  appLauncher = {
    enableClipboardHistory = false;
    autoPasteClipboard = false;
    enableClipPreview = true;
    clipboardWrapText = true;
    enableClipboardSmartIcons = true;
    enableClipboardChips = true;
    clipboardWatchTextCommand = "wl-paste --type text --watch cliphist store";
    clipboardWatchImageCommand = "wl-paste --type image --watch cliphist store";
    position = "center";
    pinnedApps = [ ];
    sortByMostUsed = true;
    terminalCommand = "ghostty -e";
    customLaunchPrefixEnabled = false;
    customLaunchPrefix = "";
    viewMode = "list";
    showCategories = true;
    iconMode = "tabler";
    showIconBackground = false;
    enableSettingsSearch = true;
    enableWindowsSearch = true;
    enableSessionSearch = true;
    ignoreMouseInput = false;
    screenshotAnnotationTool = "";
    overviewLayer = false;
    density = "default";
  };

  notifications = {
    enabled = true;
    enableMarkdown = false;
    density = "default";
    monitors = [ ];
    location = "top_right";
    overlayLayer = true;
    backgroundOpacity = 0.97;
    respectExpireTimeout = false;
    lowUrgencyDuration = 3;
    normalUrgencyDuration = 8;
    criticalUrgencyDuration = 15;
    clearDismissed = true;
    saveToHistory = {
      low = true;
      normal = true;
      critical = true;
    };
    sounds = {
      enabled = false;
      volume = 0.5;
      separateSounds = false;
      criticalSoundFile = "";
      normalSoundFile = "";
      lowSoundFile = "";
      excludedApps = "discord,firefox,chrome,chromium,edge";
    };
    enableMediaToast = false;
    enableKeyboardLayoutToast = true;
    enableBatteryToast = true;
  };

  colorSchemes = {
    useWallpaperColors = false;
    predefinedScheme = "Catppuccin";
    darkMode = true;
    schedulingMode = "off";
    manualSunrise = "06:30";
    manualSunset = "18:30";
    generationMethod = "tonal-spot";
    monitorForColors = "";
    syncGsettings = true;
  };
  wallpaper = {
    enabled = true;
    overviewEnabled = false;
    directory = "/home/da/Pictures/Wallpapers";
    monitorDirectories = [ ];
    enableMultiMonitorDirectories = false;
    showHiddenFiles = false;
    viewMode = "single";
    setWallpaperOnAllMonitors = true;
    linkLightAndDarkWallpapers = true;
    fillMode = "crop";
    fillColor = "#000000";
    useSolidColor = false;
    solidColor = "#1a1a2e";
    automationEnabled = false;
    wallpaperChangeMode = "random";
    randomIntervalSec = 300;
    transitionDuration = 1500;
    transitionType = [
      "fade"
      "disc"
      "stripes"
      "wipe"
      "pixelate"
      "honeycomb"
      "zoom"
    ];
    skipStartupTransition = false;
    transitionEdgeSmoothness = 0.3;
    panelPosition = "follow_bar";
    hideWallpaperFilenames = false;
    useOriginalImages = false;
    overviewBlur = 0.4;
    overviewTint = 0.6;
    useWallhaven = false;
    wallhavenQuery = "";
    wallhavenSorting = "relevance";
    wallhavenOrder = "desc";
    wallhavenCategories = "111";
    wallhavenPurity = "100";
    wallhavenRatios = "";
    wallhavenApiKey = "";
    wallhavenResolutionMode = "atleast";
    wallhavenResolutionWidth = "";
    wallhavenResolutionHeight = "";
    sortOrder = "name";
    favorites = [ ];
  };

  systemMonitor = {
    cpuWarningThreshold = 50;
    cpuCriticalThreshold = 90;
    tempWarningThreshold = 60;
    tempCriticalThreshold = 85;
    gpuWarningThreshold = 50;
    gpuCriticalThreshold = 95;
    memWarningThreshold = 60;
    memCriticalThreshold = 90;
    swapWarningThreshold = 20;
    swapCriticalThreshold = 80;
    diskWarningThreshold = 80;
    diskCriticalThreshold = 95;
    diskAvailWarningThreshold = 20;
    diskAvailCriticalThreshold = 10;
    batteryWarningThreshold = 10;
    batteryCriticalThreshold = 10;
    enableDgpuMonitoring = false;
    useCustomColors = false;
    warningColor = "";
    criticalColor = "";
    externalMonitor = "resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor";
  };

  noctaliaPerformance = {
    disableWallpaper = true;
    disableDesktopWidgets = true;
  };

  dock = {
    enabled = true;
    position = "bottom";
    displayMode = "always_visible";
    dockType = "floating";
    backgroundOpacity = 0.88;
    floatingRatio = 1;
    size = 1;
    onlySameOutput = true;
    monitors = [ ];
    pinnedApps = [ ];
    colorizeIcons = false;
    showLauncherIcon = false;
    launcherPosition = "end";
    launcherUseDistroLogo = false;
    launcherIcon = "";
    launcherIconColor = "none";
    pinnedStatic = false;
    inactiveIndicators = false;
    groupApps = false;
    groupContextMenuMode = "extended";
    groupClickAction = "cycle";
    groupIndicatorStyle = "dots";
    deadOpacity = 0.6;
    animationSpeed = 1;
    sitOnFrame = false;
    showDockIndicator = false;
    indicatorThickness = 3;
    indicatorColor = "primary";
    indicatorOpacity = 0.6;
  };

  network = {
    bluetoothRssiPollingEnabled = false;
    bluetoothRssiPollIntervalMs = 60000;
    networkPanelView = "wifi";
    wifiDetailsViewMode = "grid";
    bluetoothDetailsViewMode = "grid";
    bluetoothHideUnnamedDevices = false;
    disableDiscoverability = false;
    bluetoothAutoConnect = true;
  };

  sessionMenu = {
    enableCountdown = true;
    countdownDuration = 10000;
    position = "center";
    showHeader = true;
    showKeybinds = true;
    largeButtonsStyle = true;
    largeButtonsLayout = "single-row";
    powerOptions = [
      {
        action = "lock";
        enabled = true;
        keybind = "1";
      }
      {
        action = "suspend";
        enabled = true;
        keybind = "2";
      }
      {
        action = "hibernate";
        enabled = true;
        keybind = "3";
      }
      {
        action = "reboot";
        enabled = true;
        keybind = "4";
      }
      {
        action = "logout";
        enabled = true;
        keybind = "5";
      }
      {
        action = "shutdown";
        enabled = true;
        keybind = "6";
      }
      {
        action = "rebootToUefi";
        enabled = true;
        keybind = "7";
      }
    ];
  };

  osd = {
    enabled = true;
    location = "top_right";
    autoHideMs = 2000;
    overlayLayer = true;
    backgroundOpacity = 1;
    enabledTypes = [
      0
      1
      2
    ];
    monitors = [ ];
  };

  audio = {
    volumeStep = 5;
    volumeOverdrive = false;
    spectrumFrameRate = 30;
    visualizerType = "linear";
    spectrumMirrored = true;
    mprisBlacklist = [ ];
    preferredPlayer = "";
    volumeFeedback = false;
    volumeFeedbackSoundFile = "";
  };

  brightness = {
    brightnessStep = 5;
    enforceMinimum = true;
    enableDdcSupport = false;
    backlightDeviceMappings = [ ];
  };

  templates = {
    activeTemplates = [ ];
    enableUserTheming = false;
  };

  nightLight = {
    enabled = false;
    forced = false;
    autoSchedule = true;
    nightTemp = "4000";
    dayTemp = "6500";
    manualSunrise = "06:30";
    manualSunset = "18:30";
  };

  hooks = {
    enabled = false;
    wallpaperChange = "";
    darkModeChange = "";
    screenLock = "";
    screenUnlock = "";
    performanceModeEnabled = "";
    performanceModeDisabled = "";
    startup = "";
    session = "";
    colorGeneration = "";
  };

  plugins = {
    autoUpdate = true;
    notifyUpdates = true;
  };

  idle = {
    enabled = true;
    screenOffTimeout = 660;
    lockTimeout = 600;
    suspendTimeout = 900;
    fadeDuration = 9;
    screenOffCommand = "";
    lockCommand = "";
    suspendCommand = "";
    resumeScreenOffCommand = "";
    resumeLockCommand = "";
    resumeSuspendCommand = "";
    customCommands = "[]";
  };

  desktopWidgets = {
    enabled = true;
    overviewEnabled = true;
    gridSnap = false;
    gridSnapScale = false;
    monitorWidgets = [ ];
  };
}
