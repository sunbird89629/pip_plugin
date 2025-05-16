// pip_plugin.h
#ifndef FLUTTER_PLUGIN_PIP_PLUGIN_H_
#define FLUTTER_PLUGIN_PIP_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

namespace pip_plugin {

class PipPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  PipPlugin();
  ~PipPlugin() override;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  // Window procedure
  static LRESULT CALLBACK PipWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam);

  // Initialization & update routines
  void CreatePipWindow();
  void ApplyConfiguration();
  void UpdatePipText(const std::string& text);
  void NotifyPipStopped();

  // Persisted configuration
  std::wstring        window_title_{L"PiP Window"};
  COLORREF            background_color_ = RGB(0,0,0);
  BYTE                background_alpha_ = 255;
  COLORREF            text_color_       = RGB(255,255,255);
  BYTE                text_alpha_       = 255;
  int                 text_size_        = 32;           // pixel size
  UINT                text_format_      = DT_CENTER;    // DT_LEFT/DT_CENTER/DT_RIGHT
  std::vector<int>    ratio_            = {16, 9};      // aspect ratio

  // Win32 objects
  HWND                           pip_hwnd_        = nullptr;
  HFONT                          pip_font_        = nullptr;
  std::wstring                   pip_current_text_;
  bool                           pip_visible_     = false;

  // Flutter channel
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  // Window class registration
  static bool window_class_registered_;
  static const wchar_t kPipWindowClass[];
};

}  // namespace pip_plugin

#endif  // FLUTTER_PLUGIN_PIP_PLUGIN_H_
