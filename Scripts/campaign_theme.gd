extends RefCounted
class_name CampaignTheme

## Общая навy/золотая палитра интерфейса кампании — используется на экране кампании,
## подготовки к бою и выбора миссии (а также Библиотекой/Садом/Весами через
## campaign_screen.gd). Раньше эти же 7 цветов были независимо продублированы в
## campaign_screen.gd (GOD_DETAIL_*/BUTTON_OPAQUE_*), battle_setup.gd (SETUP_*) и
## mission_select.gd (_PANEL_BG/_ACCENT/...) — что давало реальный риск разъехаться
## (так и произошло: campaign_screen.gd использовал альфу фона 0.75 вместо 0.82).
## Теперь один источник правды; локальные имена в тех файлах — тонкие алиасы сюда.

const PANEL_BG := Color(0.09, 0.11, 0.20, 0.82)
const ACCENT := Color(0.83, 0.72, 0.45, 1.0)
const ACCENT_DIM := Color(0.55, 0.48, 0.32, 1.0)
const BUTTON_BG := Color(0.05, 0.06, 0.11, 1.0)
const BUTTON_BG_HOVER := Color(0.08, 0.10, 0.17, 1.0)
const BUTTON_BG_PRESSED := Color(0.03, 0.04, 0.07, 1.0)
const BUTTON_BG_DISABLED := Color(0.04, 0.05, 0.08, 1.0)
