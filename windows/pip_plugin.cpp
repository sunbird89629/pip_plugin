// pip_plugin.cpp
#include "pip_plugin.h"
#include <VersionHelpers.h>
#include <flutter/standard_method_codec.h>
#include <sstream>

namespace pip_plugin {

bool PipPlugin::window_class_registered_ = false;
const wchar_t PipPlugin::kPipWindowClass[] = L"PipPluginWindow";

void PipPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(),
          "pip_plugin",
          &flutter::StandardMethodCodec::GetInstance());

  auto* plugin = new PipPlugin();
  plugin->channel_ = std::move(channel);
  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer = plugin](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::unique_ptr<PipPlugin>(plugin));
}

PipPlugin::PipPlugin() = default;

PipPlugin::~PipPlugin() {
  if (pip_hwnd_) DestroyWindow(pip_hwnd_);
  if (pip_font_) DeleteObject(pip_font_);
}

void PipPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();

  if (method == "getPlatformVersion") {
    std::ostringstream v;
    v << "Windows ";
    if      (IsWindows10OrGreater()) v << "10+";
    else if (IsWindows8OrGreater())  v << "8";
    else if (IsWindows7OrGreater())  v << "7";
    result->Success(flutter::EncodableValue(v.str()));
    return;
  }

  if (method == "setupPip" || method == "updatePip") {
    auto maybeMap = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!maybeMap) {
      result->Error("bad_args", "Expected map of configuration");
      return;
    }
    const auto& args = *maybeMap;

    // windowTitle only on setupPip
    if (method == "setupPip") {
      if (auto it = args.find(flutter::EncodableValue("windowTitle"));
          it != args.end()) {
        if (auto s = std::get_if<std::string>(&it->second)) {
          int len = MultiByteToWideChar(
              CP_UTF8, 0, s->c_str(), -1, nullptr, 0);
          window_title_.resize(len);
          MultiByteToWideChar(
              CP_UTF8, 0, s->c_str(), -1,
              &window_title_[0], len);
          if (!window_title_.empty()) window_title_.pop_back();
        }
      }
    }

    // backgroundColor RGBA
    if (auto it = args.find(flutter::EncodableValue("backgroundColor"));
        it != args.end()) {
      if (auto list = std::get_if<flutter::EncodableList>(&it->second)) {
        int r=0,g=0,b=0,a=255;
        if (list->size()>=3) {
          r = std::get<int>(list->at(0));
          g = std::get<int>(list->at(1));
          b = std::get<int>(list->at(2));
        }
        if (list->size()>=4) {
          a = std::get<int>(list->at(3));
        }
        background_color_ = RGB(r,g,b);
        background_alpha_ = static_cast<BYTE>(a);
      }
    }

    // textColor RGBA
    if (auto it = args.find(flutter::EncodableValue("textColor"));
        it != args.end()) {
      if (auto list = std::get_if<flutter::EncodableList>(&it->second)) {
        int r=255,g=255,b=255,a=255;
        if (list->size()>=3) {
          r = std::get<int>(list->at(0));
          g = std::get<int>(list->at(1));
          b = std::get<int>(list->at(2));
        }
        if (list->size()>=4) {
          a = std::get<int>(list->at(3));
        }
        text_color_ = RGB(r,g,b);
        text_alpha_ = static_cast<BYTE>(a);
      }
    }

    // textSize
    if (auto it = args.find(flutter::EncodableValue("textSize"));
        it != args.end()) {
      if (auto d = std::get_if<double>(&it->second)) {
        text_size_ = static_cast<int>(*d);
      }
    }

    // textAlign
    if (auto it = args.find(flutter::EncodableValue("textAlign"));
        it != args.end()) {
      if (auto s = std::get_if<std::string>(&it->second)) {
        if (*s == "left")       text_format_ = DT_LEFT;
        else if (*s == "right") text_format_ = DT_RIGHT;
        else                    text_format_ = DT_CENTER;
      }
    }

    // ratio
    if (auto it = args.find(flutter::EncodableValue("ratio"));
        it != args.end()) {
      if (auto list = std::get_if<flutter::EncodableList>(&it->second)) {
        if (list->size() >= 2) {
          ratio_.assign({
            std::get<int>(list->at(0)),
            std::get<int>(list->at(1))
          });
        }
      }
    }

    if (method == "setupPip") {
      CreatePipWindow();
    } else {
      ApplyConfiguration();
    }
    UpdatePipText("");
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method == "startPip") {
    if (!pip_hwnd_) {
      result->Error("not_ready", "PiP has not been set up");
    } else {
      ShowWindow(pip_hwnd_, SW_SHOW);
      pip_visible_ = true;
      result->Success(flutter::EncodableValue(true));
    }
    return;
  }

  if (method == "stopPip") {
    if (!pip_hwnd_) {
      result->Error("not_ready", "PiP has not been set up");
    } else {
      ShowWindow(pip_hwnd_, SW_HIDE);
      pip_visible_ = false;
      result->Success(flutter::EncodableValue(true));
    }
    return;
  }

  if (method == "updateText") {
    if (auto args = std::get_if<flutter::EncodableMap>(call.arguments())) {
      if (auto it = args->find(flutter::EncodableValue("text"));
          it != args->end()) {
        if (auto s = std::get_if<std::string>(&it->second)) {
          UpdatePipText(*s);
          result->Success(flutter::EncodableValue(true));
          return;
        }
      }
    }
    result->Error("invalid_argument", "Text cannot be empty");
    return;
  }

  if (method == "isPipSupported") {
    result->Success(flutter::EncodableValue(true));
    return;
  }

  result->NotImplemented();
}

void PipPlugin::CreatePipWindow() {
  if (pip_hwnd_) return;

  if (!window_class_registered_) {
    WNDCLASS wc = {};
    wc.lpfnWndProc   = PipWndProc;
    wc.hInstance     = GetModuleHandle(nullptr);
    wc.lpszClassName = kPipWindowClass;
    wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
    RegisterClass(&wc);
    window_class_registered_ = true;
  }

  int h = 180;
  int w = static_cast<int>(h * ratio_[0] / (double)ratio_[1]);
  DWORD ex = WS_EX_TOPMOST | WS_EX_LAYERED;
  pip_hwnd_ = CreateWindowEx(
      ex,
      kPipWindowClass,
      window_title_.c_str(),
      WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT, CW_USEDEFAULT, w, h,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  SetLayeredWindowAttributes(pip_hwnd_, 0, background_alpha_, LWA_ALPHA);

  ApplyConfiguration();
}

void PipPlugin::ApplyConfiguration() {
  if (pip_font_) {
    DeleteObject(pip_font_);
    pip_font_ = nullptr;
  }
  pip_font_ = CreateFont(
      -text_size_, 0, 0, 0, FW_BOLD,
      FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_OUTLINE_PRECIS,
      CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
      VARIABLE_PITCH, L"Consolas");

  if (pip_hwnd_) {
    SetLayeredWindowAttributes(pip_hwnd_, 0, background_alpha_, LWA_ALPHA);

    RECT rc;
    GetWindowRect(pip_hwnd_, &rc);
    int currentHeight = rc.bottom - rc.top;
    int newWidth = static_cast<int>(currentHeight * ratio_[0] / (double)ratio_[1]);
    SetWindowPos(pip_hwnd_, nullptr,
                 0, 0, newWidth, currentHeight,
                 SWP_NOMOVE | SWP_NOZORDER);

    InvalidateRect(pip_hwnd_, nullptr, TRUE);
    UpdateWindow(pip_hwnd_);
  }
}

void PipPlugin::UpdatePipText(const std::string& text) {
  int len = MultiByteToWideChar(
      CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
  if (len <= 0) return;
  std::wstring wtext(len, L'\0');
  MultiByteToWideChar(
      CP_UTF8, 0, text.c_str(), -1, &wtext[0], len);
  if (!wtext.empty()) wtext.pop_back();

  pip_current_text_ = std::move(wtext);

  if (pip_hwnd_) {
    InvalidateRect(pip_hwnd_, nullptr, TRUE);
    UpdateWindow(pip_hwnd_);
  }
}

void PipPlugin::NotifyPipStopped() {
  if (channel_) {
    channel_->InvokeMethod("pipStopped", nullptr);
  }
}

LRESULT CALLBACK PipPlugin::PipWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  PipPlugin* self = nullptr;
  if (msg == WM_NCCREATE) {
    auto cs = reinterpret_cast<CREATESTRUCT*>(lParam);
    self = reinterpret_cast<PipPlugin*>(cs->lpCreateParams);
    SetWindowLongPtr(hwnd, GWLP_USERDATA, (LONG_PTR)self);
  } else {
    self = reinterpret_cast<PipPlugin*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  }

  switch (msg) {
    case WM_PAINT: {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint(hwnd, &ps);
      RECT rc; GetClientRect(hwnd, &rc);
      
      // Background
      HBRUSH brush = CreateSolidBrush(self->background_color_);
      FillRect(hdc, &rc, brush);
      DeleteObject(brush);

      // Text
      SetBkMode(hdc, TRANSPARENT);
      SetTextColor(hdc, self->text_color_);
      HFONT old = (HFONT)SelectObject(hdc, self->pip_font_);

      DrawTextW(
          hdc,
          self->pip_current_text_.c_str(),
          -1,
          &rc,
          self->text_format_
          | DT_VCENTER
          | DT_SINGLELINE);

      SelectObject(hdc, old);
      EndPaint(hwnd, &ps);
      return 0;
    }

    case WM_SIZING: {
      if (!self) break;
      RECT* r = reinterpret_cast<RECT*>(lParam);
      int w = r->right - r->left;
      int h = r->bottom - r->top;
      double ar = double(self->ratio_[0]) / self->ratio_[1];
      if (w * self->ratio_[1] >= h * self->ratio_[0]) {
        w = int(h * ar);
      } else {
        h = int(w / ar);
      }
      r->right  = r->left + w;
      r->bottom = r->top + h;
      return TRUE;
    }

    case WM_DESTROY: {
      if (self) {
        self->pip_hwnd_    = nullptr;
        self->pip_visible_ = false;
        self->NotifyPipStopped();
      }
      break;
    }
  }
  return DefWindowProc(hwnd, msg, wParam, lParam);
}

}  // namespace pip_plugin

