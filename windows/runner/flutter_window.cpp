#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <memory>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

int ReadUnreadCount(const flutter::EncodableValue* arguments) {
  if (arguments == nullptr) return 0;
  const auto* map = std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) return 0;
  const auto iterator = map->find(flutter::EncodableValue("unreadCount"));
  if (iterator == map->end()) return 0;
  if (const auto* value = std::get_if<int32_t>(&iterator->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&iterator->second)) {
    return static_cast<int>(*value);
  }
  return 0;
}

bool ReadAttentionRaised(const flutter::EncodableValue* arguments) {
  if (arguments == nullptr) return false;
  const auto* map = std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) return false;
  const auto iterator = map->find(flutter::EncodableValue("attentionRaised"));
  if (iterator == map->end()) return false;
  const auto* value = std::get_if<bool>(&iterator->second);
  return value != nullptr && *value;
}

void RegisterApplicationAttentionChannel(
    flutter::FlutterEngine* engine, FlutterWindow* window) {
  FlutterDesktopPluginRegistrarRef plugin_registrar_ref =
      engine->GetRegistrarForPlugin("YorksApplicationAttention");
  auto* registrar = flutter::PluginRegistrarManager::GetInstance()
                        ->GetRegistrar<flutter::PluginRegistrarWindows>(
                            plugin_registrar_ref);
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.yorks.app/application_attention",
          &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([window](const auto& call, auto result) {
    if (call.method_name() == "playNotificationAlert") {
      MessageBeep(MB_ICONASTERISK);
      result->Success();
      return;
    }
    if (call.method_name() != "setAttention") {
      result->NotImplemented();
      return;
    }
    window->SetApplicationAttention(
        ReadUnreadCount(call.arguments()),
        ReadAttentionRaised(call.arguments()));
    result->Success();
  });
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterApplicationAttentionChannel(flutter_controller_->engine(), this);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SetApplicationAttention(int unread_count,
                                            bool attention_raised) {
  const int safe_count = unread_count < 0 ? 0 : unread_count;
  const std::wstring badge = safe_count > 99
      ? L"99+"
      : std::to_wstring(safe_count);
  const std::wstring title = safe_count > 0
      ? L"(" + badge + L") Yorks AC. & Ref."
      : L"Yorks AC. & Ref.";
  if (HWND window = GetHandle()) {
    SetWindowText(window, title.c_str());
    if (attention_raised && GetForegroundWindow() != window) {
      FLASHWINFO flash{};
      flash.cbSize = sizeof(flash);
      flash.hwnd = window;
      flash.dwFlags = FLASHW_TRAY | FLASHW_TIMER;
      flash.uCount = 3;
      flash.dwTimeout = 0;
      FlashWindowEx(&flash);
    }
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
